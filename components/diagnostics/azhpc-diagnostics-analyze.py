#!/usr/bin/env python3
"""azhpc-diagnostics-analyze: automated checks over collected facts.

Usage: azhpc-diagnostics-analyze.py <directory containing facts.json>

Reads only facts.json and never runs commands against the system, so it also works offline on an
extracted diagnostics bundle or on build evidence. Writes findings.json and findings.txt into the
same directory and prints findings.txt.

Checks against the VM's hardware (GPUs, NVSwitches, InfiniBand, hardware-dependent services) only
run when the hardware collection tier ran. Image builds may run on general-purpose VMs, so build
evidence only gets the general checks.

Must keep working on Python 3.6 (platform-python on EL8 images).
"""

import json
import os
import sys

ANALYZER_VERSION = "1.0.0"
FORMAT_VERSION = "1"
SEVERITY_RANK = {"ERROR": 0, "WARN": 1, "INFO": 2}

# Services that should stay active once enabled. One-shot services are excluded, nvidia-fabricmanager
# is checked against the NVSwitches instead, and nvidia-imex against the VM size when it is known.
PERSISTENT_SERVICES = {"waagent", "walinuxagent", "sku-customizations", "openibd", "nvidia-persistenced",
                       "nvidia-imex", "nvidia-dcgm", "docker", "sunrpc_tcp_settings", "nvme-raid"}


def finding(severity, check, message):
    return {"severity": severity, "check": check, "message": message}


def gpu_checks(f, vendor, name, observed, driver_loaded, driver, tool, listed):
    """Intended hardware comes from the VM size (expected_hardware); the PCI bus only says what is
    visible. A device that should be there but is not visible points at the VM allocation or the
    host, while a visible device without a working driver points at the image."""
    exp = f.get("expected_hardware") or {}
    known = exp.get("known", False)
    expected = exp.get("gpu_vendor") == vendor
    size = (f.get("vm") or {}).get("size")
    count = exp.get("gpu_count")
    out = []
    if known and expected and observed == 0:
        out.append(finding("ERROR", vendor + "-gpu-presence",
                           "VM size {} should have {} {} GPU(s) but none are visible on the PCI bus. This points at "
                           "the VM allocation or host rather than the GPU driver.".format(
                               size, count if count is not None else "one or more", name)))
    elif known and expected and count is not None and observed < count:
        out.append(finding("ERROR", vendor + "-gpu-presence",
                           "VM size {} should have {} {} GPU(s) but only {} are visible on the PCI bus".format(
                               size, count, name, observed)))
    elif known and not expected and observed > 0:
        out.append(finding("WARN", vendor + "-gpu-presence",
                           "{} {} GPU(s) are visible on the PCI bus but VM size {} is not expected to have any".format(
                               observed, name, size)))
    if observed > 0 and not driver_loaded:
        out.append(finding("ERROR", vendor + "-driver",
                           "{} kernel driver is not loaded but {} {} GPU(s) are visible on the PCI bus".format(
                               driver, observed, name)))
    elif observed > 0 and (listed or 0) < observed:
        out.append(finding("ERROR", vendor + "-driver",
                           "{} lists {} of the {} {} GPU(s) visible on the PCI bus".format(
                               tool, listed or 0, observed, name)))
    return out


def general_checks(f):
    """Checks that make sense on any VM, including image build VMs."""
    out = []
    running_kernel = (f.get("os") or {}).get("kernel")
    dkms = f.get("dkms") or []
    missing = sorted({e["module"] for e in dkms}
                     - {e["module"] for e in dkms
                        if e.get("kernel") == running_kernel and (e.get("status") or "").startswith("installed")})
    if missing:
        out.append(finding("WARN", "dkms", "DKMS module(s) not installed for the running kernel {}: {} "
                           "(see system/dkms-status.txt)".format(running_kernel, ", ".join(missing))))

    image = f.get("image") or {}
    image_kernel = (image.get("build_manifest") or {}).get("kernel") or (image.get("component_versions") or {}).get("KERNEL")
    # TODO: with DKMS (and prebuilt kmod packages such as Ubuntu linux-modules-nvidia-* that DKMS
    # does not track), a kernel other than the image kernel is not necessarily a problem. Replace
    # this hint with a per-module check of what is available for the running kernel.
    if image_kernel and running_kernel and image_kernel != running_kernel:
        out.append(finding("INFO", "kernel", "Running kernel {} differs from the image kernel {}. DKMS modules are "
                           "checked separately; other kernel modules shipped with the image may not be built for this "
                           "kernel.".format(running_kernel, image_kernel)))

    use = (f.get("filesystems") or {}).get("root_use_percent")
    if use is not None and use >= 90:
        out.append(finding("WARN", "disk", "Root file system is {}% full".format(use)))

    timeouts = [c.get("command") for c in f.get("commands") or [] if c.get("status") == "TIMEOUT"]
    if timeouts:
        out.append(finding("WARN", "timeouts", "Commands timed out (possible hung device or driver): " + "; ".join(timeouts)))
    return out


def hardware_checks(f):
    """Checks against the hardware of the VM the data was collected on."""
    out = []
    exp = f.get("expected_hardware") or {}
    known = exp.get("known", False)
    size = (f.get("vm") or {}).get("size")
    pci = f.get("pci") or {}
    modules = set(f.get("kernel_modules") or [])
    services = f.get("services") or []
    manifest = (f.get("image") or {}).get("build_manifest")
    gpus = f.get("gpus") or {}
    nv = gpus.get("nvidia") or {}
    amd = gpus.get("amd") or {}
    ib_ports = [p for p in (f.get("rdma") or {}).get("ports") or [] if p.get("link_layer") == "InfiniBand"]

    if size is None:
        out.append(finding("INFO", "vm-size", "VM size is unknown (Azure Instance Metadata Service is unreachable); "
                           "checks against the intended hardware of the VM size were skipped"))
    elif not known:
        out.append(finding("INFO", "vm-size", "VM size {} is not in the known HPC/AI VM size table; checks against its "
                           "intended hardware were skipped".format(size)))

    # Image deployed on hardware of another GPU vendor (e.g. an NVIDIA image on an MI300X VM)
    platform = (manifest or {}).get("gpu_platform") or ""
    if known and exp.get("gpu_vendor") in ("nvidia", "amd") and platform not in ("", "unknown") \
            and platform.lower() != exp["gpu_vendor"]:
        out.append(finding("ERROR", "image-hardware-match",
                           "This image was built for {} GPUs (GPU SKU {}, image version {}) but VM size {} has {} GPUs. "
                           "Deploy the image that matches the VM size.".format(
                               platform, manifest.get("gpu_sku") or "unknown", manifest.get("image_version") or "unknown",
                               size, exp["gpu_vendor"].upper())))

    # NVIDIA
    out += gpu_checks(f, "nvidia", "NVIDIA", pci.get("nvidia_gpus") or 0, nv.get("driver_loaded", False),
                      "NVIDIA", "nvidia-smi", len(nv.get("devices") or []))
    xids = nv.get("xid_counts") or {}
    if xids:
        out.append(finding("WARN", "nvidia-xid", "NVIDIA Xid errors in kernel log: "
                           + ", ".join("{} (x{})".format(k, v) for k, v in xids.items())))
    ecc = ["GPU {} ({}): {}".format(g.get("index"), g.get("bus_id"), g["ecc_uncorrected_volatile"])
           for g in nv.get("devices") or [] if (g.get("ecc_uncorrected_volatile") or 0) > 0]
    if ecc:
        out.append(finding("WARN", "nvidia-ecc", "Uncorrectable volatile ECC errors: " + "; ".join(ecc)))
    remap = ["GPU {} ({}): pending={} failure={}".format(r.get("index"), r.get("bus_id"), r.get("pending"), r.get("failure"))
             for r in nv.get("remapped_rows") or []
             if "Yes" in (r.get("pending") or "") or "Yes" in (r.get("failure") or "")]
    if remap:
        out.append(finding("WARN", "nvidia-row-remap", "GPU row remapping pending or failed (pending needs a GPU reset "
                           "or reboot): " + "; ".join(remap)))
    if nv.get("driver_loaded") and ib_ports and "nvidia_peermem" not in modules:
        out.append(finding("WARN", "nvidia-peermem",
                           "nvidia_peermem module is not loaded; GPUDirect RDMA over InfiniBand is unavailable"))
    nvswitches = pci.get("nvswitches") or 0
    if exp.get("nvswitch") and nvswitches == 0:
        out.append(finding("ERROR", "nvswitch-presence", "VM size {} should have NVSwitches but none are visible on the "
                           "PCI bus; CUDA and NCCL will fail on this VM".format(size)))
    elif nvswitches > 0 and not any(s.get("name") == "nvidia-fabricmanager" and s.get("active_state") == "active"
                                    for s in services):
        out.append(finding("ERROR", "nvidia-fabricmanager", "nvidia-fabricmanager is not active but {} NVSwitch(es) are "
                           "visible on the PCI bus; CUDA and NCCL will fail on this VM "
                           "(see services/nvidia-fabricmanager.txt)".format(nvswitches)))
    # Rack-scale NVLink (GB200/GB300, Vera Rubin NVL72) has no NVSwitches on the VM's PCI bus and uses
    # nvidia-imex instead of nvidia-fabricmanager. Only cross-VM GPU communication by host workloads
    # needs IMEX, and IMEX needs the VMs of the NVLink domain in its node list (often managed per job by
    # the scheduler), so this is only a warning.
    imex_checked = bool(exp.get("imex")) and (pci.get("nvidia_gpus") or 0) > 0
    if imex_checked:
        imex = next((s for s in services if s.get("name") == "nvidia-imex"), None)
        imex_scope = ("nvidia-imex is required for GPU communication between VMs over multi-node NVLink (e.g. NCCL "
                      "across VMs) by workloads running on the host. It is not needed for single-VM workloads, or for "
                      "containerized workloads where the container platform runs its own IMEX daemons (e.g. NVIDIA "
                      "DRA driver ComputeDomains on Kubernetes).")
        if imex is None or imex.get("load_state") == "not-found":
            out.append(finding("WARN", "nvidia-imex", "nvidia-imex is not installed but VM size {} is part of a "
                               "multi-node NVLink domain. {}".format(size, imex_scope)))
        elif imex.get("active_state") != "active":
            out.append(finding("WARN", "nvidia-imex", "nvidia-imex is {} but VM size {} is part of a multi-node NVLink "
                               "domain. {} To enable it, list the VMs of the NVLink domain in "
                               "/etc/nvidia-imex/nodes_config.cfg and start nvidia-imex "
                               "(see services/nvidia-imex.txt).".format(imex.get("active_state"), size, imex_scope)))

    # AMD
    amd_gpus = pci.get("amd_gpus") or 0
    out += gpu_checks(f, "amd", "AMD", amd_gpus, amd.get("driver_loaded", False), "amdgpu", "amd-smi",
                      amd.get("smi_visible") or 0)
    amd_ecc = ["GPU {}: {}".format(e.get("gpu"), e.get("count")) for e in amd.get("ecc_uncorrectable") or []
               if (e.get("count") or 0) > 0]
    if amd_ecc:
        out.append(finding("WARN", "amd-ecc", "Uncorrectable ECC errors: " + "; ".join(amd_ecc)))
    if amd_gpus > 0 and amd.get("driver_loaded") and not amd.get("ecc_uncorrectable"):
        out.append(finding("INFO", "amd-ecc", "ECC error counts are unavailable (neither amd-smi metric nor the amdgpu "
                           "RAS sysfs counters reported any); uncorrectable ECC errors were not checked"))

    # InfiniBand
    controllers = pci.get("infiniband_controllers") or 0
    if exp.get("infiniband") and not ib_ports:
        if controllers == 0:
            out.append(finding("ERROR", "infiniband-presence", "VM size {} should have InfiniBand but no InfiniBand "
                               "controller is visible on the PCI bus. This points at the VM allocation or host rather "
                               "than the NIC driver.".format(size)))
        elif "mlx5_ib" not in modules:
            out.append(finding("ERROR", "infiniband-driver", "{} InfiniBand controller(s) are visible on the PCI bus but "
                               "the mlx5_ib driver is not loaded".format(controllers)))
        else:
            out.append(finding("ERROR", "infiniband-driver", "{} InfiniBand controller(s) are visible on the PCI bus but "
                               "no InfiniBand port is registered (see infiniband/)".format(controllers)))
    elif exp.get("infiniband") is None and controllers > 0 and not ib_ports:
        out.append(finding("ERROR", "infiniband-driver", "{} InfiniBand controller(s) are visible on the PCI bus but no "
                           "InfiniBand port is registered (is the mlx5_ib driver loaded?)".format(controllers)))
    for p in ib_ports:
        state = p.get("state") or "unknown"
        if "ACTIVE" not in state:
            out.append(finding("WARN", "infiniband-port", "InfiniBand port {}/{} is {}".format(
                p.get("device"), p.get("port"), state.split(": ", 1)[-1])))

    # Services, many of which depend on the hardware (GPU, InfiniBand, NVMe)
    for s in services:
        if s.get("name") == "nvidia-imex" and imex_checked:
            continue
        if s.get("name") in PERSISTENT_SERVICES and s.get("unit_file_state") == "enabled" \
                and s.get("active_state") != "active":
            out.append(finding("WARN", "service", "Service {} is enabled but {} (see services/{}.txt)".format(
                s["name"], s.get("active_state"), s["name"])))
    if f.get("failed_units"):
        out.append(finding("WARN", "systemd", "Failed systemd units: " + " ".join(f["failed_units"])))
    return out


def analyze(f):
    findings = [finding(n.get("severity"), "collector", n.get("message")) for n in f.get("notes") or []]
    if "hardware" in (f.get("tiers") or []):
        findings += hardware_checks(f)
    findings += general_checks(f)
    return sorted(findings, key=lambda x: SEVERITY_RANK.get(x["severity"], 3))


def main():
    if len(sys.argv) != 2 or sys.argv[1] in ("-h", "--help"):
        sys.stderr.write("Usage: {} <directory containing facts.json>\n".format(os.path.basename(sys.argv[0])))
        sys.exit(2)
    d = sys.argv[1]
    try:
        with open(os.path.join(d, "facts.json"), encoding="utf-8") as fh:
            facts = json.load(fh)
    except (OSError, ValueError) as e:
        sys.exit("ERROR: cannot read {}: {}".format(os.path.join(d, "facts.json"), e))

    result = {"format_version": FORMAT_VERSION, "analyzer_version": ANALYZER_VERSION,
              "facts_format_version": facts.get("format_version"), "context": facts.get("context"),
              "findings": analyze(facts)}
    tmp = os.path.join(d, "findings.json.tmp")
    with open(tmp, "w", encoding="utf-8") as fh:
        json.dump(result, fh, indent=2, ensure_ascii=False)
        fh.write("\n")
    os.replace(tmp, os.path.join(d, "findings.json"))

    text = "".join("{:<5} {}\n".format(x["severity"], x["message"]) for x in result["findings"])
    with open(os.path.join(d, "findings.txt"), "w", encoding="utf-8") as fh:
        fh.write(text)
    sys.stdout.write(text)


if __name__ == "__main__":
    main()
