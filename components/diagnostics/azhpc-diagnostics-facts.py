#!/usr/bin/env python3
"""azhpc-diagnostics-facts: structure collected data into facts.json.

Subcommands:
  facts <dir> --context diagnostics|build ...
      Parse the raw output that azhpc-collect-lib.sh wrote to <dir> into <dir>/facts.json.
      Only reads files in <dir>, so it can be re-run offline on an extracted bundle or on
      build evidence.
  sku-hardware [--field NAME] <VM size>
      Print the hardware a VM size is supposed to have.
  build-manifest --output FILE [--dkms-status FILE]
      Write the image build manifest (run at image build time; build context from IMAGE_VERSION,
      TARGET_VM_SIZE, BUILD_VM_SIZE, GPU_SKU, GPU_PLATFORM and TARGET_NODE_TYPE).

Must keep working on Python 3.6 (platform-python on EL8 images).
"""

import argparse
import datetime
import fnmatch
import json
import os
import re
import sys

FORMAT_VERSION = "1"

# Hardware each VM size is supposed to have:
#   (VM size patterns, GPU vendor, GPU count, InfiniBand, NVSwitch, IMEX); None means unknown.
# NVSwitch means NVSwitches on the VM's PCI bus, managed by nvidia-fabricmanager. IMEX means a
# rack-scale (multi-node) NVLink domain such as GB200/GB300 NVL72 or Vera Rubin NVL72, where the
# NVSwitches sit in separate switch trays and nvidia-imex is used instead of nvidia-fabricmanager.
# The VM size from IMDS is the source of truth for the intended hardware. The PCI bus only shows
# what is visible, so it can't tell "driver or device broken" from "not part of this VM size".
# TODO: non-Azure environments (no IMDS, e.g. bare metal) need a reliable hint of the intended
# hardware. Until then everything is unknown there and the checks fall back to what is observed.
SKU_HARDWARE = [
    (("standard_nd40rs_v2",), "nvidia", 8, True, False, False),
    (("standard_nd96asr_v4", "standard_nd96amsr_a100_v4"), "nvidia", 8, True, True, False),
    (("standard_nc24ads_a100_v4",), "nvidia", 1, False, False, False),
    (("standard_nc48ads_a100_v4",), "nvidia", 2, False, False, False),
    (("standard_nc96ads_a100_v4",), "nvidia", 4, False, False, False),
    (("standard_nc40ads_h100_v5",), "nvidia", 1, False, False, False),
    (("standard_nc80adis_h100_v5",), "nvidia", 2, False, False, False),
    (("standard_nd96is*_h[12]00_v5",), "nvidia", 8, True, True, False),
    (("standard_nd96isr_mi300x_v5",), "amd", 8, True, False, False),
    (("standard_nd128is*_gb[23]00_v6",), "nvidia", 4, True, False, True),
    (("standard_nd168isr_vr_nvl72_v7",), "nvidia", None, None, None, True),
    (("standard_nc*_rtxpro6000bse_v6",), "nvidia", None, False, False, False),
    (("standard_hb*", "standard_hc*", "standard_hx*"), "none", 0, True, False, False),
]

EXIT_CODE_RE = re.compile(r"^\[exit code: (-?\d+)\]$")
# 'dkms status' in the old ("mod, ver, kernel, arch: status") and new ("mod/ver, kernel, arch: status") format
DKMS_RE = re.compile(r"^(?P<module>[^/, ]+)[/,] ?(?P<version>[^,:]+)"
                     r"(?:, (?P<kernel>[^,:]+), (?P<arch>[^:]+))?: (?P<status>.+)$")
XID_RE = re.compile(r"NVRM: Xid \([^)]*\): (\d+)")
IB_SYSFS_RE = re.compile(r"^/sys/class/infiniband/([^/]+)/ports/([^/]+)/(state|phys_state|link_layer|rate):(.*)$")
AMD_RAS_RE = re.compile(r"^/sys/bus/pci/devices/([^/]*)/ras/[^:]*_err_count:ue: *(\d+)$")


def sku_hardware(vm_size):
    size = (vm_size or "").lower()
    for patterns, vendor, count, infiniband, nvswitch, imex in SKU_HARDWARE:
        if any(fnmatch.fnmatchcase(size, p) for p in patterns):
            return {"known": True, "gpu_vendor": vendor, "gpu_count": count,
                    "infiniband": infiniband, "nvswitch": nvswitch, "imex": imex}
    return {"known": False, "gpu_vendor": None, "gpu_count": None, "infiniband": None, "nvswitch": None,
            "imex": None}


####################################################################################################
# Readers
####################################################################################################

def read_text(path):
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            return f.read()
    except OSError:
        return None


def read_json(path):
    text = read_text(path)
    if text is None:
        return None
    try:
        return json.loads(text)
    except ValueError:
        return None


def output_lines(path):
    """Output lines of a collected file, None if it wasn't collected.

    Files written by azc_run frame each command as "$ <command>", a blank line, the output and
    "[exit code: N]"; the framing is dropped. Plain copies and raw output are returned as-is.
    """
    text = read_text(path)
    if text is None:
        return None
    lines = text.splitlines()
    if not lines or not lines[0].startswith("$ "):
        return lines
    out = []
    inside = header = False
    for line in lines:
        if not inside:
            if line.startswith("$ "):
                inside = header = True
            continue
        if EXIT_CODE_RE.match(line):
            inside = False
            continue
        if header:
            header = False
            if line == "":
                continue
        out.append(line)
    return out


def number(value):
    value = (value or "").strip()
    for convert in (int, float):
        try:
            return convert(value)
        except ValueError:
            pass
    return None


def tsv_rows(path, skip_header=False):
    text = read_text(path)
    if text is None:
        return []
    rows = [line.split("\t") for line in text.splitlines() if line.strip()]
    return rows[1:] if skip_header else rows


####################################################################################################
# Parsers
####################################################################################################

def parse_os_release(lines):
    values = {}
    for line in lines or []:
        key, sep, value = line.partition("=")
        if sep and key.strip() and not key.startswith("#"):
            values[key.strip()] = value.strip().strip('"').strip("'")
    return values


def parse_dkms(lines):
    entries = []
    for line in lines or []:
        m = DKMS_RE.match(line.strip())
        if m:
            entries.append(m.groupdict())
    return entries


def parse_modules(lines):
    return [line.split()[0] for line in lines or [] if line.strip() and not line.startswith("Module ")]


def parse_pci(lines):
    counts = {"nvidia_gpus": 0, "nvswitches": 0, "amd_gpus": 0, "infiniband_controllers": 0}
    for line in lines or []:
        fields = line.split()
        if len(fields) != 4 or not fields[1].startswith("0x"):
            continue
        vendor, device_class = fields[1].lower(), fields[3].lower()
        if vendor == "0x10de" and device_class.startswith("0x03"):
            counts["nvidia_gpus"] += 1
        if vendor == "0x10de" and device_class.startswith("0x0680"):
            counts["nvswitches"] += 1
        if vendor == "0x1002" and device_class.startswith(("0x03", "0x12")):
            counts["amd_gpus"] += 1
        if device_class.startswith("0x0207"):
            counts["infiniband_controllers"] += 1
    return counts


def parse_rdma_ports(lines):
    ports = {}
    for line in lines or []:
        m = IB_SYSFS_RE.match(line)
        if not m:
            continue
        device, port, attribute, value = m.groups()
        entry = ports.setdefault((device, port), {"device": device, "port": number(port) if port.isdigit() else port})
        entry[attribute] = value.strip()
    return list(ports.values())


def parse_services(lines):
    services, block = [], {}
    for line in (lines or []) + [""]:
        if not line.strip():
            if block.get("Id"):
                name = block["Id"]
                services.append({
                    "name": name[:-len(".service")] if name.endswith(".service") else name,
                    "load_state": block.get("LoadState"),
                    "unit_file_state": block.get("UnitFileState"),
                    "active_state": block.get("ActiveState"),
                    "sub_state": block.get("SubState"),
                })
            block = {}
            continue
        key, sep, value = line.partition("=")
        if sep:
            block[key] = value
    return services


def parse_root_use(lines):
    for line in lines or []:
        fields = line.split()
        if fields and fields[-1] == "/":
            for field in fields:
                if re.match(r"^\d+%$", field):
                    return int(field[:-1])
    return None


def csv_rows(lines):
    """Data rows of an nvidia-smi --format=csv query (the header and errors are skipped)."""
    return [line.split(", ") for line in lines or [] if re.match(r"^\d+, ", line)]


def parse_nvidia(d, modules):
    query = output_lines(os.path.join(d, "nvidia", "nvidia-smi-query.txt"))
    remapped = output_lines(os.path.join(d, "nvidia", "nvidia-smi-remapped-rows.txt"))
    driver = output_lines(os.path.join(d, "system", "nvidia-driver-version.txt"))
    xids = {}
    for line in output_lines(os.path.join(d, "system", "dmesg.txt")) or []:
        m = XID_RE.search(line)
        if m:
            xids[m.group(1)] = xids.get(m.group(1), 0) + 1
    devices = []
    for f in csv_rows(query):
        f += [""] * (10 - len(f))
        devices.append({"index": number(f[0]), "bus_id": f[1], "name": f[2], "serial": f[3], "uuid": f[4],
                        "driver_version": f[5], "vbios_version": f[6], "persistence_mode": f[7],
                        "ecc_uncorrected_volatile": number(f[8]), "temperature_c": number(f[9])})
    rows = []
    for f in csv_rows(remapped):
        f += [""] * (4 - len(f))
        rows.append({"index": number(f[0]), "bus_id": f[1], "pending": f[2], "failure": f[3]})
    return {
        "driver_loaded": "nvidia" in modules,
        "driver_version": driver[0].strip() if driver else None,
        "smi_ran": query is not None,
        "devices": devices,
        "remapped_rows": rows,
        "xid_counts": dict(sorted(xids.items(), key=lambda kv: int(kv[0]))),
    }


def parse_amd(d, modules):
    listing = output_lines(os.path.join(d, "amd", "amd-smi-list.txt"))
    ecc, gpu = [], None
    for line in output_lines(os.path.join(d, "amd", "amd-smi-metric.txt")) or []:
        m = re.match(r"^GPU: (\S+)", line)
        if m:
            gpu = number(m.group(1)) if m.group(1).isdigit() else m.group(1)
            continue
        m = re.match(r"^\s*TOTAL_UNCORRECTABLE_COUNT:\s*(\d+)\s*$", line)
        if m:
            ecc.append({"gpu": gpu, "count": int(m.group(1))})
    source = "amd-smi" if ecc else None
    if not ecc:
        # Sum of uncorrectable errors over all RAS blocks, per GPU (PCI address)
        totals = {}
        for line in output_lines(os.path.join(d, "amd", "ras-sysfs.txt")) or []:
            m = AMD_RAS_RE.match(line)
            if m:
                totals[m.group(1)] = totals.get(m.group(1), 0) + int(m.group(2))
        ecc = [{"gpu": k, "count": v} for k, v in sorted(totals.items())]
        source = "sysfs" if ecc else None
    return {
        "driver_loaded": "amdgpu" in modules,
        "smi_visible": None if listing is None else sum(1 for line in listing if line.startswith("GPU: ")),
        "ecc_source": source,
        "ecc_uncorrectable": ecc,
    }


def option_value(text):
    try:
        return json.loads(text)
    except ValueError:
        return text


####################################################################################################
# Subcommands
####################################################################################################

def build_facts(d, args):
    def path(*parts):
        return os.path.join(d, *parts)

    def first(rel):
        lines = output_lines(path(*rel.split("/")))
        return lines[0].strip() if lines and lines[0].strip() else None

    modules = parse_modules(output_lines(path("system", "lsmod.txt")))
    os_release = parse_os_release(output_lines(path("system", "os-release")))
    vm_size = first("image/vm-size.txt")
    commands = [{"status": r[0], "exit_code": number(r[1]), "duration_s": number(r[2].rstrip("s")),
                 "output": r[3], "command": r[4]}
                for r in tsv_rows(path("commands.tsv"), skip_header=True) if len(r) >= 5]
    failed = output_lines(path("system", "systemctl-failed.txt"))
    options = {}
    for opt in args.option or []:
        key, _, value = opt.partition("=")
        options[key] = option_value(value)
    return {
        "format_version": FORMAT_VERSION,
        "context": args.context,
        "collector": {"name": args.collector, "version": args.collector_version, "lib_version": args.lib_version},
        "collected_at": datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
        "hostname": first("system/hostname.txt"),
        "tiers": [line.strip() for line in output_lines(path("tiers.txt")) or [] if line.strip()],
        "options": options,
        "vm": {"size": vm_size, "source": "imds" if vm_size else None},
        "expected_hardware": sku_hardware(vm_size),
        "pci": parse_pci(output_lines(path("hardware", "pci-devices.txt"))),
        "os": {"id": os_release.get("ID"), "version_id": os_release.get("VERSION_ID"),
               "pretty_name": os_release.get("PRETTY_NAME"),
               "kernel": first("system/kernel-release.txt"), "arch": first("system/machine.txt")},
        "image": {"component_versions": read_json(path("image", "component_versions.json")),
                  "build_manifest": read_json(path("image", "build-manifest.json"))},
        "kernel_modules": modules,
        "dkms": parse_dkms(output_lines(path("system", "dkms-status.txt"))),
        "rdma": {"ports": parse_rdma_ports(output_lines(path("infiniband", "sysfs.txt")))},
        "services": parse_services(output_lines(path("services", "states.txt"))),
        "failed_units": [line.split()[0] for line in failed or [] if line.strip()],
        "filesystems": {"root_use_percent": parse_root_use(output_lines(path("system", "df.txt")))},
        "gpus": {"nvidia": parse_nvidia(d, modules), "amd": parse_amd(d, modules)},
        "commands": commands,
        "notes": [{"severity": r[0], "message": r[1] if len(r) > 1 else ""} for r in tsv_rows(path("notes.tsv"))],
    }


def write_json(path, data):
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
        f.write("\n")
    os.replace(tmp, path)


def cmd_facts(args):
    if not os.path.isdir(args.dir):
        sys.exit("ERROR: {} is not a directory".format(args.dir))
    write_json(os.path.join(args.dir, "facts.json"), build_facts(args.dir, args))


def cmd_sku_hardware(args):
    hardware = sku_hardware(args.vm_size)
    if args.field:
        value = hardware.get(args.field)
        print("unknown" if value is None else value)
    else:
        print(json.dumps(hardware))


def cmd_build_manifest(args):
    env = os.environ.get
    os_release = parse_os_release(output_lines("/etc/os-release"))
    uname = os.uname()
    write_json(args.output, {
        "format_version": FORMAT_VERSION,
        "image_version": env("IMAGE_VERSION", "unknown"),
        "target_vm_size": env("TARGET_VM_SIZE", "unknown"),
        "build_vm_size": env("BUILD_VM_SIZE", "unknown"),
        "gpu_sku": env("GPU_SKU", "unknown"),
        "gpu_platform": env("GPU_PLATFORM", "unknown"),
        "target_node_type": env("TARGET_NODE_TYPE", "unknown"),
        "built_at": datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
        "kernel": uname.release,
        "arch": uname.machine,
        "os": {"id": os_release.get("ID"), "version_id": os_release.get("VERSION_ID")},
        "dkms": parse_dkms(output_lines(args.dkms_status)) if args.dkms_status else [],
    })


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    sub = parser.add_subparsers(dest="command")
    sub.required = True

    p = sub.add_parser("facts", help="write <dir>/facts.json from the collected data in <dir>")
    p.add_argument("dir")
    p.add_argument("--context", required=True, choices=["diagnostics", "build"])
    p.add_argument("--collector", required=True)
    p.add_argument("--collector-version", required=True)
    p.add_argument("--lib-version")
    p.add_argument("--option", action="append", metavar="KEY=VALUE", help="collection option to record")
    p.set_defaults(func=cmd_facts)

    p = sub.add_parser("sku-hardware", help="print the hardware a VM size is supposed to have")
    p.add_argument("vm_size")
    p.add_argument("--field", choices=["known", "gpu_vendor", "gpu_count", "infiniband", "nvswitch", "imex"])
    p.set_defaults(func=cmd_sku_hardware)

    p = sub.add_parser("build-manifest", help="write the image build manifest")
    p.add_argument("--output", required=True)
    p.add_argument("--dkms-status", help="file with 'dkms status' output")
    p.set_defaults(func=cmd_build_manifest)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
