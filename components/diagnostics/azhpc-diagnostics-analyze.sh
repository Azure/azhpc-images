#!/bin/bash
#
# azhpc-diagnostics-analyze: automated checks over collected facts.
#
# Usage: azhpc-diagnostics-analyze.sh <directory containing facts.json>
#
# Reads only facts.json (schema/facts.schema.json) and never runs commands against the system,
# so it also works offline on an extracted diagnostics bundle or on build evidence. Writes
# findings.json (schema/findings.schema.json) and findings.txt into the same directory and prints
# findings.txt.

set -euo pipefail

ANALYZER_VERSION="1.0.0"
FINDINGS_SCHEMA_VERSION="1.0"

# Services that should stay active once enabled. One-shot services are excluded, and
# nvidia-fabricmanager is checked against the NVSwitches instead.
PERSISTENT_SERVICES='["waagent", "walinuxagent", "sku-customizations", "openibd", "nvidia-persistenced",
    "nvidia-imex", "nvidia-dcgm", "docker", "sunrpc_tcp_settings", "nvme-raid"]'

dir=${1:-}
if [ -z "$dir" ] || [ "$dir" = -h ] || [ "$dir" = --help ]; then
    echo "Usage: $(basename "$0") <directory containing facts.json>" >&2
    exit 2
fi
facts="$dir/facts.json"
[ -r "$facts" ] || { echo "ERROR: $facts not found" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "ERROR: jq is required" >&2; exit 1; }
trap 'rm -f "$dir/findings.json.tmp"' EXIT

jq --arg schema_version "$FINDINGS_SCHEMA_VERSION" --arg analyzer_version "$ANALYZER_VERSION" \
   --argjson persistent "$PERSISTENT_SERVICES" '
def finding($severity; $check; $message): {severity: $severity, check: $check, message: $message};
def has_module($mods; $m): any($mods[]; . == $m);
def rank: {"ERROR": 0, "WARN": 1, "INFO": 2}[.severity] // 3;

# Intended hardware comes from the VM size (expected_hardware); the PCI bus only says what is
# visible. A device that should be there but is not visible points at the VM allocation or the
# host, while a visible device without a working driver points at the image.
# gpu_checks($f; vendor; display name; visible on PCI; driver loaded; driver name; tool; GPUs listed by tool)
def gpu_checks($f; $vendor; $name; $observed; $driver_loaded; $driver; $tool; $listed):
    ($f.expected_hardware // {}) as $exp
    | ($exp.known // false) as $known
    | ($exp.gpu_vendor == $vendor) as $expected
    | (if $known and $expected and $observed == 0 then
           finding("ERROR"; "\($vendor)-gpu-presence"; "VM size \($f.vm.size) should have \($exp.gpu_count // "one or more") \($name) GPU(s) but none are visible on the PCI bus. This points at the VM allocation or host rather than the GPU driver.")
       elif $known and $expected and $exp.gpu_count != null and $observed < $exp.gpu_count then
           finding("ERROR"; "\($vendor)-gpu-presence"; "VM size \($f.vm.size) should have \($exp.gpu_count) \($name) GPU(s) but only \($observed) are visible on the PCI bus")
       elif $known and ($expected | not) and $observed > 0 then
           finding("WARN"; "\($vendor)-gpu-presence"; "\($observed) \($name) GPU(s) are visible on the PCI bus but VM size \($f.vm.size) is not expected to have any")
       else empty end),
      (if $observed > 0 and ($driver_loaded | not) then
           finding("ERROR"; "\($vendor)-driver"; "\($driver) kernel driver is not loaded but \($observed) \($name) GPU(s) are visible on the PCI bus")
       elif $observed > 0 and ($listed // 0) < $observed then
           finding("ERROR"; "\($vendor)-driver"; "\($tool) lists \($listed // 0) of the \($observed) \($name) GPU(s) visible on the PCI bus")
       else empty end);

. as $f
| ($f.expected_hardware // {}) as $exp
| ($exp.known // false) as $known
| ($f.vm.size // null) as $size
| ($f.pci // {}) as $pci
| ($f.kernel_modules // []) as $mods
| ($f.services // []) as $services
| ($f.image.build_manifest // null) as $manifest
| ($f.gpus.nvidia // {}) as $nv
| ($f.gpus.amd // {}) as $amd
| ([$f.rdma.ports[]? | select(.link_layer == "InfiniBand")]) as $ib_ports
| ($f.os.kernel // null) as $running_kernel
| ($f.dkms // []) as $dkms
| ([$dkms[].module] | unique) as $dkms_modules
| ([$dkms_modules[] as $m
     | select(any($dkms[]; .module == $m and .kernel == $running_kernel
                           and ((.status // "") | startswith("installed"))) | not)
     | $m]) as $dkms_missing
| (($manifest.kernel // null) // ($f.image.component_versions.KERNEL // null)) as $image_kernel
| [
    # Issues the collector ran into (missing tools, interrupted collection, ...)
    ($f.notes[]? | finding(.severity; "collector"; .message)),

    (if $size == null then
         finding("INFO"; "vm-size"; "VM size is unknown (Azure Instance Metadata Service is unreachable); checks against the intended hardware of the VM size were skipped")
     elif ($known | not) then
         finding("INFO"; "vm-size"; "VM size \($size) is not in the known HPC/AI VM size table; checks against its intended hardware were skipped")
     else empty end),

    # Image deployed on hardware of another GPU vendor (e.g. an NVIDIA image on an MI300X VM)
    (if $manifest != null and $known and ($exp.gpu_vendor == "nvidia" or $exp.gpu_vendor == "amd")
        and (($manifest.gpu_platform // "") != "")
        and (($manifest.gpu_platform | ascii_downcase) != $exp.gpu_vendor) then
         finding("ERROR"; "image-hardware-match"; "This image was built for \($manifest.gpu_platform) GPUs (GPU SKU \($manifest.gpu_sku // "unknown"), image version \($manifest.image_version // "unknown")) but VM size \($size) has \($exp.gpu_vendor | ascii_upcase) GPUs. Deploy the image that matches the VM size.")
     else empty end),

    # NVIDIA
    gpu_checks($f; "nvidia"; "NVIDIA"; ($pci.nvidia_gpus // 0); ($nv.driver_loaded // false);
               "NVIDIA"; "nvidia-smi"; ($nv.devices // [] | length)),
    (($nv.xid_counts // {}) | to_entries
        | if length > 0 then finding("WARN"; "nvidia-xid"; "NVIDIA Xid errors in kernel log: " + (map("\(.key) (x\(.value))") | join(", "))) else empty end),
    ([$nv.devices[]? | select((.ecc_uncorrected_volatile // 0) > 0)
        | "GPU \(.index) (\(.bus_id)): \(.ecc_uncorrected_volatile)"]
        | if length > 0 then finding("WARN"; "nvidia-ecc"; "Uncorrectable volatile ECC errors: " + join("; ")) else empty end),
    ([$nv.remapped_rows[]? | select(((.pending // "") | test("Yes")) or ((.failure // "") | test("Yes")))
        | "GPU \(.index) (\(.bus_id)): pending=\(.pending) failure=\(.failure)"]
        | if length > 0 then finding("WARN"; "nvidia-row-remap"; "GPU row remapping pending or failed (pending needs a GPU reset or reboot): " + join("; ")) else empty end),
    (if ($nv.driver_loaded // false) and ($ib_ports | length) > 0 and (has_module($mods; "nvidia_peermem") | not) then
         finding("WARN"; "nvidia-peermem"; "nvidia_peermem module is not loaded; GPUDirect RDMA over InfiniBand is unavailable")
     else empty end),
    (if ($exp.nvswitch // false) and ($pci.nvswitches // 0) == 0 then
         finding("ERROR"; "nvswitch-presence"; "VM size \($size) should have NVSwitches but none are visible on the PCI bus; CUDA and NCCL will fail on this VM")
     elif ($pci.nvswitches // 0) > 0
          and (any($services[]; .name == "nvidia-fabricmanager" and .active_state == "active") | not) then
         finding("ERROR"; "nvidia-fabricmanager"; "nvidia-fabricmanager is not active but \($pci.nvswitches) NVSwitch(es) are visible on the PCI bus; CUDA and NCCL will fail on this VM (see services/nvidia-fabricmanager.txt)")
     else empty end),

    # AMD
    gpu_checks($f; "amd"; "AMD"; ($pci.amd_gpus // 0); ($amd.driver_loaded // false);
               "amdgpu"; "amd-smi"; ($amd.smi_visible // 0)),
    ([$amd.ecc_uncorrectable[]? | select(.count > 0) | "GPU \(.gpu): \(.count)"]
        | if length > 0 then finding("WARN"; "amd-ecc"; "Uncorrectable ECC errors: " + join("; ")) else empty end),

    # InfiniBand
    (if ($exp.infiniband // false) and ($ib_ports | length) == 0 then
         if ($pci.infiniband_controllers // 0) == 0 then
             finding("ERROR"; "infiniband-presence"; "VM size \($size) should have InfiniBand but no InfiniBand controller is visible on the PCI bus. This points at the VM allocation or host rather than the NIC driver.")
         elif (has_module($mods; "mlx5_ib") | not) then
             finding("ERROR"; "infiniband-driver"; "\($pci.infiniband_controllers) InfiniBand controller(s) are visible on the PCI bus but the mlx5_ib driver is not loaded")
         else
             finding("ERROR"; "infiniband-driver"; "\($pci.infiniband_controllers) InfiniBand controller(s) are visible on the PCI bus but no InfiniBand port is registered (see infiniband/)")
         end
     elif $exp.infiniband == null and ($pci.infiniband_controllers // 0) > 0 and ($ib_ports | length) == 0 then
         finding("ERROR"; "infiniband-driver"; "\($pci.infiniband_controllers) InfiniBand controller(s) are visible on the PCI bus but no InfiniBand port is registered (is the mlx5_ib driver loaded?)")
     else empty end),
    ($ib_ports[] | select((.state // "") | test("ACTIVE") | not)
        | finding("WARN"; "infiniband-port"; "InfiniBand port \(.device)/\(.port) is \((.state // "unknown") | sub("^[0-9]+: "; ""))")),

    # OS
    ($services[] | . as $s
        | select(any($persistent[]; . == $s.name))
        | select(.unit_file_state == "enabled" and .active_state != "active")
        | finding("WARN"; "service"; "Service \(.name) is enabled but \(.active_state) (see services/\(.name).txt)")),
    (($f.failed_units // []) | if length > 0 then finding("WARN"; "systemd"; "Failed systemd units: " + join(" ")) else empty end),
    (($f.filesystems.root_use_percent // 0) as $use
        | if $use >= 90 then finding("WARN"; "disk"; "Root file system is \($use)% full") else empty end),
    (if ($dkms_missing | length) > 0 then
         finding("WARN"; "dkms"; "DKMS module(s) not installed for the running kernel \($running_kernel): \($dkms_missing | join(", ")) (see system/dkms-status.txt)")
     else empty end),
    # TODO: with DKMS (and prebuilt kmod packages such as Ubuntu linux-modules-nvidia-* that DKMS
    # does not track), a kernel other than the image kernel is not necessarily a problem. Replace
    # this hint with a per-module check of what is available for the running kernel.
    (if $image_kernel != null and $running_kernel != null and $image_kernel != $running_kernel then
         finding("INFO"; "kernel"; "Running kernel \($running_kernel) differs from the image kernel \($image_kernel). DKMS modules are checked separately; other kernel modules shipped with the image may not be built for this kernel.")
     else empty end),

    ([($f.commands // [])[] | select(.status == "TIMEOUT") | .command]
        | if length > 0 then finding("WARN"; "timeouts"; "Commands timed out (possible hung device or driver): " + join("; ")) else empty end)
  ]
| {schema_version: $schema_version, analyzer_version: $analyzer_version,
   facts_schema_version: $f.schema_version, context: $f.context,
   findings: sort_by(rank)}
' "$facts" > "$dir/findings.json.tmp"
mv "$dir/findings.json.tmp" "$dir/findings.json"

jq -r '.findings[] | [.severity, .message] | @tsv' "$dir/findings.json" |
    while IFS=$'\t' read -r severity message; do
        printf '%-5s %s\n' "$severity" "$message"
    done > "$dir/findings.txt"

cat "$dir/findings.txt"
