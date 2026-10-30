# shellcheck shell=bash
#
# azhpc-collect-lib: data collection shared by azhpc-diagnostics (support bundles) and
# packer/scripts/collect_build_evidence.sh (image build evidence). Source it; it only defines
# functions and variables.
#
# Collection is separate from analysis: the azc_collect_* functions write raw command output
# and azc_write_facts structures it into facts.json (schema/facts.schema.json).
# azhpc-diagnostics-analyze.sh reads only facts.json and never runs commands on the system.
#
# All functions are safe under 'set -euo pipefail'. Failing commands are recorded in
# commands.tsv and never abort the caller.
#
# Layout of $AZC_DIR:
#   commands.tsv  status, exit code, duration, output file and command line of every command
#   notes.tsv     collector notes (severity, message), reported as findings by the analyzer
#   facts.json    structured facts (schema/facts.schema.json)
#   system/ hardware/ network/ infiniband/ services/ logs/ software/ image/ nvidia/ amd/

AZC_LIB_VERSION="1.0.0"
AZC_FACTS_SCHEMA_VERSION="1.0"
AZC_TIMEOUT=${AZC_TIMEOUT:-120}
AZC_COMPONENT_VERSIONS_FILE=/opt/azurehpc/component_versions.txt
AZC_BUILD_MANIFEST_FILE=/opt/azurehpc/diagnostics/build-manifest.json
AZC_DIR=${AZC_DIR:-}
AZC_LOG=${AZC_LOG:-/dev/null}
# Services whose status and journal are collected (used by the callers)
# shellcheck disable=SC2034
AZC_SERVICES="waagent walinuxagent sku-customizations openibd azure_persistent_rdma_naming \
nvidia-persistenced nvidia-fabricmanager nvidia-imex nvidia-dcgm rocmstartup docker \
sunrpc_tcp_settings nvme-raid"

####################################################################################################
# Helpers
####################################################################################################

# azc_init <output dir> [log file]
azc_init() {
    AZC_DIR=$1
    AZC_LOG=${2:-$1/collector.log}
    mkdir -p "$AZC_DIR"
    [ -f "$AZC_DIR/commands.tsv" ] || printf 'STATUS\tEXIT\tDURATION\tOUTPUT\tCOMMAND\n' > "$AZC_DIR/commands.tsv"
    touch "$AZC_DIR/notes.tsv"
}

azc_log() {
    printf '[%s] %s\n' "$(date -u +%H:%M:%S)" "$*" | tee -a "$AZC_LOG"
}

# azc_note <ERROR|WARN|INFO> <message>
azc_note() {
    printf '%s\t%s\n' "$1" "$(printf '%s' "$2" | tr -s '\t\n' ' ')" >> "$AZC_DIR/notes.tsv"
}

# azc_run_t <timeout> <output file relative to $AZC_DIR> <command> [args...]
azc_run_t() {
    local t="$1" rel="$2"
    shift 2
    local out="$AZC_DIR/$rel" start rc=0 status
    if ! command -v "$1" >/dev/null 2>&1; then
        printf 'SKIPPED\t-\t0s\t%s\t%s (not installed)\n' "$rel" "$*" >> "$AZC_DIR/commands.tsv"
        return 0
    fi
    mkdir -p "$(dirname "$out")"
    printf '$ %s\n\n' "$*" >> "$out"
    start=$SECONDS
    timeout -k 10 "$t" "$@" >> "$out" 2>&1 < /dev/null || rc=$?
    printf '\n[exit code: %s]\n\n' "$rc" >> "$out"
    case $rc in
        0) status=OK ;;
        124|137) status=TIMEOUT ;;
        *) status=FAIL ;;
    esac
    printf '%s\t%s\t%ss\t%s\t%s\n' "$status" "$rc" "$((SECONDS - start))" "$rel" \
        "$(printf '%s' "$*" | tr -s '\t\n ' ' ')" >> "$AZC_DIR/commands.tsv"
    return 0
}

azc_run() {
    azc_run_t "$AZC_TIMEOUT" "$@"
}

# azc_run_sh <output file> <shell snippet>
azc_run_sh() {
    azc_run_t "$AZC_TIMEOUT" "$1" bash -c "$2"
}

# azc_copy_file <destination relative to $AZC_DIR> <source>
azc_copy_file() {
    [ -f "$2" ] || return 0
    mkdir -p "$(dirname "$AZC_DIR/$1")"
    cp -L "$2" "$AZC_DIR/$1" 2>> "$AZC_LOG" || true
}

# azc_copy_paths <destination dir relative to $AZC_DIR> <path>... (keeps the source path)
azc_copy_paths() {
    local dest="$AZC_DIR/$1" p
    shift
    for p in "$@"; do
        [ -e "$p" ] || continue
        mkdir -p "$dest"
        cp -a --parents "$p" "$dest" 2>> "$AZC_LOG" || true
    done
}

# azc_tail_log <destination dir relative to $AZC_DIR> <file> [lines]
azc_tail_log() {
    [ -f "$2" ] || return 0
    mkdir -p "$AZC_DIR/$1"
    tail -n "${3:-50000}" "$2" > "$AZC_DIR/$1/$(basename "$2")" 2>> "$AZC_LOG" || true
}

# azc_imds <path> [extra query]
azc_imds() {
    curl -sf --noproxy '*' --connect-timeout 2 --max-time 5 -H Metadata:true \
        "http://169.254.169.254/metadata/instance/$1?api-version=2021-02-01${2:-}" 2>/dev/null || true
}

# azc_pci_count <vendor regex> <class regex>: number of matching PCI functions
azc_pci_count() {
    local d n=0
    for d in /sys/bus/pci/devices/*; do
        [ -r "$d/vendor" ] && [ -r "$d/class" ] || continue
        grep -Eq "$1" "$d/vendor" && grep -Eq "$2" "$d/class" && n=$((n + 1))
    done
    echo "$n"
}

####################################################################################################
# Intended vs. observed hardware
####################################################################################################

# azc_sku_hardware <Azure VM size>
# Prints the hardware the VM size is supposed to have:
#   <gpu vendor: nvidia|amd|none|unknown> <gpu count|-> <infiniband: yes|no|unknown> <nvswitch: yes|no|unknown>
# The VM size from IMDS is the source of truth for the intended hardware. The PCI bus only shows
# what is visible, so it can't tell "driver/device broken" from "not part of this VM size".
# TODO: non-Azure environments (no IMDS, e.g. bare metal) need a reliable hint of the intended
# hardware. Until then everything is "unknown" there and checks fall back to what is observed.
azc_sku_hardware() {
    local size
    size=$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]')
    case "$size" in
        standard_nd40rs_v2)                            echo "nvidia 8 yes no" ;;
        standard_nd96asr_v4|standard_nd96amsr_a100_v4) echo "nvidia 8 yes yes" ;;
        standard_nc24ads_a100_v4)                      echo "nvidia 1 no no" ;;
        standard_nc48ads_a100_v4)                      echo "nvidia 2 no no" ;;
        standard_nc96ads_a100_v4)                      echo "nvidia 4 no no" ;;
        standard_nc40ads_h100_v5)                      echo "nvidia 1 no no" ;;
        standard_nc80adis_h100_v5)                     echo "nvidia 2 no no" ;;
        standard_nd96is*_h[12]00_v5)                   echo "nvidia 8 yes yes" ;;
        standard_nd96isr_mi300x_v5)                    echo "amd 8 yes no" ;;
        standard_nd128is*_gb[23]00_v6)                 echo "nvidia 4 yes no" ;;
        standard_nd128isr_vr200_v6)                    echo "nvidia - unknown unknown" ;;
        standard_nc*_rtxpro6000bse_v6)                 echo "nvidia - no no" ;;
        standard_hb*|standard_hc*|standard_hx*)        echo "none 0 yes no" ;;
        *)                                             echo "unknown - unknown unknown" ;;
    esac
}

# azc_detect: sets AZC_VM_SIZE, AZC_EXPECT_* (intended hardware) and AZC_PCI_* (observed hardware)
azc_detect() {
    AZC_VM_SIZE=$(azc_imds compute/vmSize '&format=text')
    read -r AZC_EXPECT_GPU_VENDOR AZC_EXPECT_GPU_COUNT AZC_EXPECT_IB AZC_EXPECT_NVSWITCH \
        <<< "$(azc_sku_hardware "$AZC_VM_SIZE")"
    AZC_PCI_NVIDIA_GPUS=$(azc_pci_count '^0x10de$' '^0x03')
    AZC_PCI_NVSWITCHES=$(azc_pci_count '^0x10de$' '^0x0680')
    AZC_PCI_AMD_GPUS=$(azc_pci_count '^0x1002$' '^0x(03|12)')
    AZC_PCI_IB_CONTROLLERS=$(azc_pci_count '.' '^0x0207')
}

# Vendor-specific GPU collection runs if the VM size should have the vendor's GPUs, or if any
# are visible (unknown or mismatched VM size)
azc_want_nvidia() {
    [ "${AZC_EXPECT_GPU_VENDOR:-unknown}" = nvidia ] || [ "${AZC_PCI_NVIDIA_GPUS:-0}" -gt 0 ]
}

azc_want_amd() {
    [ "${AZC_EXPECT_GPU_VENDOR:-unknown}" = amd ] || [ "${AZC_PCI_AMD_GPUS:-0}" -gt 0 ]
}

####################################################################################################
# Collection (GPU- and NIC-agnostic)
####################################################################################################

azc_collect_image() {
    azc_log "Collecting image information"
    azc_copy_file image/component_versions.json "$AZC_COMPONENT_VERSIONS_FILE"
    azc_copy_file image/build-manifest.json "$AZC_BUILD_MANIFEST_FILE"
    azc_copy_file image/os-release.txt /etc/os-release
}

azc_collect_os() {
    azc_log "Collecting OS information"
    azc_run system/uname.txt uname -a
    azc_run system/uptime.txt uptime
    azc_run system/page-size.txt getconf PAGESIZE
    azc_run system/cmdline.txt cat /proc/cmdline
    azc_run system/virtualization.txt systemd-detect-virt
    azc_run system/free.txt free -h
    azc_run system/df.txt df -hT
    azc_run system/lsblk.txt lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT,MODEL
    azc_run system/findmnt.txt findmnt -R /
    azc_run_sh system/ulimit.txt 'ulimit -a'
    azc_run system/sysctl.txt sysctl -a
    azc_run system/getenforce.txt getenforce
    azc_copy_paths system/config /etc/security/limits.conf /etc/security/limits.d /etc/modprobe.d
}

azc_collect_hardware() {
    azc_log "Collecting hardware and kernel information"
    azc_run hardware/lscpu.txt lscpu
    azc_run hardware/numactl.txt numactl -H
    azc_run hardware/lspci.txt lspci -nn
    azc_run hardware/lspci-tree.txt lspci -tvnn
    azc_run hardware/lspci-verbose.txt lspci -vvv -nn
    azc_run hardware/dmidecode.txt dmidecode
    azc_run system/lsmod.txt lsmod
    azc_run system/dmesg.txt dmesg -T
}

azc_collect_software_state() {
    azc_log "Collecting packages, DKMS and systemd state"
    azc_run system/dkms-status.txt dkms status
    azc_run system/journal-errors.txt journalctl -b -p err --no-pager -o short-iso
    azc_run system/journal-previous-boot-errors.txt journalctl -b -1 -p err --no-pager -o short-iso
    azc_run system/systemctl-failed.txt systemctl --failed --no-pager
    azc_run system/systemctl-services.txt systemctl list-units --type=service --all --no-pager
    if command -v dpkg-query >/dev/null 2>&1; then
        azc_run system/packages.txt dpkg-query -W -f '${Status}\t${Package}\t${Version}\t${Architecture}\n'
        azc_run system/packages-held.txt apt-mark showhold
        # Only repository fields, no inline keys
        azc_run_sh system/repositories.txt \
            "grep -RHsE '^[[:space:]]*(deb(-src)?[[:space:]]|Types:|URIs:|Suites:|Components:|Architectures:|Signed-By:[[:space:]]+/)' /etc/apt/sources.list /etc/apt/sources.list.d; true"
    else
        azc_run_sh system/packages.txt "rpm -qa --qf '%{NAME}\t%{EPOCHNUM}:%{VERSION}-%{RELEASE}\t%{ARCH}\n' | sort"
        azc_run system/packages-held.txt dnf versionlock list
        azc_run_t 60 system/repositories.txt dnf repolist --all
        azc_copy_file system/dnf.conf /etc/dnf/dnf.conf
    fi
}

# azc_collect_services <service>...
azc_collect_services() {
    azc_log "Collecting service status"
    local svc
    for svc in "$@"; do
        systemctl cat "$svc.service" >/dev/null 2>&1 || continue
        # exit 3 = not running, normal for one-shot units
        azc_run_sh "services/$svc.txt" "systemctl status --no-pager -l $svc.service || [ \$? -eq 3 ]"
        azc_run "services/$svc.txt" journalctl -b -u "$svc.service" --no-pager -n 500 -o short-iso
    done
}

azc_collect_logs() {
    azc_log "Collecting log files"
    local f
    for f in /var/log/waagent.log /var/log/cloud-init.log /var/log/cloud-init-output.log \
             /var/log/syslog /var/log/messages; do
        azc_tail_log logs "$f"
    done
    # VM extension logs
    if [ -d /var/log/azure ]; then
        mkdir -p "$AZC_DIR/logs"
        find /var/log/azure -type f -size -20M -exec cp --parents {} "$AZC_DIR/logs" \; 2>> "$AZC_LOG" || true
    fi
}

# Always runs, whatever the GPU vendor and whatever is on the PCI bus: GPU vendor reports don't
# cover every NIC (or exist on every platform), and a missing device is itself worth reporting.
azc_collect_network() {
    azc_log "Collecting network and RDMA information"
    azc_run network/ip-addr.txt ip addr
    azc_run network/ip-link-stats.txt ip -s link
    azc_run network/ip-route.txt ip route
    azc_run_sh network/ethtool.txt 'for i in /sys/class/net/*; do i=${i##*/}; [ "$i" = lo ] && continue; echo "== $i"; ethtool -i "$i" 2>&1; echo; done'
    azc_run_sh network/ethtool-stats.txt 'for i in /sys/class/net/*; do i=${i##*/}; [ "$i" = lo ] && continue; echo "== $i"; ethtool -S "$i" 2>&1; echo; done'
    azc_copy_file network/waagent.conf /etc/waagent.conf
    azc_run network/rdma-link.txt rdma link
    azc_run infiniband/ofed_info.txt ofed_info -s
    azc_run infiniband/ibstat.txt ibstat
    azc_run infiniband/ibv_devinfo.txt ibv_devinfo -v
    azc_run infiniband/ibdev2netdev.txt ibdev2netdev -v
    azc_run_sh infiniband/sysfs.txt 'for d in /sys/class/infiniband/*; do
        [ -d "$d" ] || continue
        grep -H . "$d"/fw_ver "$d"/board_id "$d"/hca_type "$d"/node_guid 2>/dev/null
        for p in "$d"/ports/*; do
            grep -H . "$p"/state "$p"/phys_state "$p"/rate "$p"/link_layer "$p"/lid "$p"/sm_lid "$p"/pkeys/0 "$p"/pkeys/1 2>/dev/null
        done
    done; true'
    azc_run_sh infiniband/port-counters.txt 'grep -H . /sys/class/infiniband/*/ports/*/counters/* /sys/class/infiniband/*/ports/*/hw_counters/* 2>/dev/null; true'
}

azc_collect_hpc_stack() {
    azc_log "Collecting MPI, NCCL and container configuration"
    azc_run software/opt.txt ls -la /opt /opt/azurehpc /opt/microsoft
    azc_run_t 60 software/modules.txt bash -lc 'module avail 2>&1'
    azc_copy_file software/nccl.conf /etc/nccl.conf
    azc_run_sh software/ldconfig-comm-libs.txt "ldconfig -p | grep -Ei 'nccl|rccl|sharp|ucx|ucc|gdrapi|libfabric'"
    azc_run_t 30 software/docker-info.txt docker info
    azc_copy_file software/docker-daemon.json /etc/docker/daemon.json
}

# Read-only GPU queries. Their output is parsed into facts.json.
azc_collect_nvidia() {
    azc_log "Collecting NVIDIA GPU information"
    azc_run nvidia/nvidia-smi-query.txt nvidia-smi --format=csv \
        --query-gpu=index,pci.bus_id,name,serial,uuid,driver_version,vbios_version,persistence_mode,ecc.errors.uncorrected.volatile.total,temperature.gpu
    azc_run nvidia/nvidia-smi-remapped-rows.txt nvidia-smi --format=csv \
        --query-gpu=index,pci.bus_id,remapped_rows.pending,remapped_rows.failure
    azc_run nvidia/nvidia-smi-topo.txt nvidia-smi topo -m
}

azc_collect_amd() {
    azc_log "Collecting AMD GPU information"
    azc_copy_file amd/rocm-version.txt /opt/rocm/.info/version
    azc_run amd/amd-smi-version.txt amd-smi version
    azc_run amd/amd-smi-list.txt amd-smi list
    azc_run amd/amd-smi-static.txt amd-smi static
    azc_run amd/amd-smi-firmware.txt amd-smi firmware
    azc_run amd/amd-smi-metric.txt amd-smi metric
    # amdgpu RAS error counters ("ue: N" / "ce: N" per IP block). Fallback for the ECC check:
    # amd-smi before 25.x doesn't report ECC in VMs. Read errors are kept to show why counters
    # are missing (the driver may reject reads on a virtual function).
    azc_run_sh amd/ras-sysfs.txt 'for d in /sys/bus/pci/devices/*; do
        [ "$(cat "$d/vendor" 2>/dev/null)" = 0x1002 ] || continue
        if [ ! -d "$d/ras" ]; then echo "${d##*/}: no ras directory"; continue; fi
        for f in "$d"/ras/*_err_count; do
            if [ ! -e "$f" ]; then echo "${d##*/}: no ras/*_err_count files"; break; fi
            grep -H . "$f" 2>&1
        done
    done; true'
    azc_run amd/amd-smi-xgmi.txt amd-smi xgmi
    azc_run amd/rocminfo.txt rocminfo
}

####################################################################################################
# Structuring: facts.json (schema/facts.schema.json)
####################################################################################################

azc_lines_json() {
    jq -Rn '[inputs | select(length > 0)]'
}

azc_expected_json() {
    jq -n --arg v "${AZC_EXPECT_GPU_VENDOR:-unknown}" --arg c "${AZC_EXPECT_GPU_COUNT:--}" \
        --arg ib "${AZC_EXPECT_IB:-unknown}" --arg nvs "${AZC_EXPECT_NVSWITCH:-unknown}" '
        def tri: if . == "yes" then true elif . == "no" then false else null end;
        {known: ($v != "unknown"),
         gpu_vendor: (if $v == "unknown" then null else $v end),
         gpu_count: ($c | tonumber? // null),
         infiniband: ($ib | tri),
         nvswitch: ($nvs | tri)}'
}

azc_rdma_ports_json() {
    local d p
    for d in /sys/class/infiniband/*; do
        [ -d "$d" ] || continue
        for p in "$d"/ports/*; do
            [ -d "$p" ] || continue
            printf '%s\t%s\t%s\t%s\t%s\t%s\n' "${d##*/}" "${p##*/}" \
                "$(cat "$p/state" 2>/dev/null)" "$(cat "$p/phys_state" 2>/dev/null)" \
                "$(cat "$p/link_layer" 2>/dev/null)" "$(cat "$p/rate" 2>/dev/null)"
        done
    done | jq -Rn '[inputs | split("\t") | {device: .[0], port: (.[1] | tonumber? // .[1]),
        state: .[2], phys_state: .[3], link_layer: .[4], rate: .[5]}]'
}

# azc_services_json <service>...
azc_services_json() {
    local svc
    for svc in "$@"; do
        systemctl show -p LoadState -p UnitFileState -p ActiveState -p SubState "$svc.service" 2>/dev/null |
            jq -Rn --arg name "$svc" '[inputs | capture("^(?<key>[^=]+)=(?<value>.*)$")] | from_entries |
                {name: $name, load_state: .LoadState, unit_file_state: .UnitFileState,
                 active_state: .ActiveState, sub_state: .SubState}'
    done | jq -s .
}

# Parses 'dkms status' in both the old ("mod, ver, kernel, arch: status") and the new
# ("mod/ver, kernel, arch: status") format
azc_dkms_json() {
    if [ -f "$AZC_DIR/system/dkms-status.txt" ]; then
        cat "$AZC_DIR/system/dkms-status.txt"
    fi | jq -Rn '[inputs
        | capture("^(?<module>[^/, ]+)[/,] ?(?<version>[^,:]+)(, (?<kernel>[^,:]+), (?<arch>[^:]+))?: (?<status>.+)$")?]'
}

azc_nvidia_json() {
    local q="$AZC_DIR/nvidia/nvidia-smi-query.txt" r="$AZC_DIR/nvidia/nvidia-smi-remapped-rows.txt"
    local driver="" xids
    [ -r /proc/driver/nvidia/version ] && driver=$(head -1 /proc/driver/nvidia/version 2>/dev/null || true)
    xids=$( (grep -oE 'NVRM: Xid \([^)]*\): [0-9]+' "$AZC_DIR/system/dmesg.txt" 2>/dev/null || true) |
        awk '{print $NF}' | sort -n | uniq -c |
        jq -Rn '[inputs | capture("^ *(?<value>[0-9]+) (?<key>[0-9]+)$") | .value |= tonumber] | from_entries')
    [ -n "$xids" ] || xids='{}'
    {
        if [ -f "$q" ]; then cat "$q"; fi
        echo '---'
        if [ -f "$r" ]; then cat "$r"; fi
    } | jq -Rn --arg driver "$driver" --argjson xids "$xids" --argjson ran "$([ -f "$q" ] && echo true || echo false)" '
        def num: tonumber? // null;
        [inputs] as $lines
        | ($lines | index("---")) as $sep
        | {driver_loaded: ($driver != ""),
           driver_version: (if $driver == "" then null else $driver end),
           smi_ran: $ran,
           devices: [$lines[:$sep][] | select(test("^[0-9]+, ")) | split(", ")
               | {index: (.[0] | num), bus_id: .[1], name: .[2], serial: .[3], uuid: .[4],
                  driver_version: .[5], vbios_version: .[6], persistence_mode: .[7],
                  ecc_uncorrected_volatile: (.[8] | num), temperature_c: (.[9] | num)}],
           remapped_rows: [$lines[$sep + 1:][] | select(test("^[0-9]+, ")) | split(", ")
               | {index: (.[0] | num), bus_id: .[1], pending: .[2], failure: .[3]}],
           xid_counts: $xids}'
}

azc_amd_json() {
    local l="$AZC_DIR/amd/amd-smi-list.txt" m="$AZC_DIR/amd/amd-smi-metric.txt" r="$AZC_DIR/amd/ras-sysfs.txt"
    local visible=null ecc source=null
    if [ -f "$l" ]; then
        visible=$(grep -c '^GPU: ' "$l" || true)
    fi
    ecc=$( (awk '/^GPU: / {g = $2} /TOTAL_UNCORRECTABLE_COUNT:/ && $2 ~ /^[0-9]+$/ {print g "\t" $2}' "$m" 2>/dev/null || true) |
        jq -Rn '[inputs | split("\t") | {gpu: (.[0] | tonumber? // .[0]), count: (.[1] | tonumber)}]')
    if [ "$(printf '%s' "${ecc:-[]}" | jq length)" -gt 0 ]; then
        source='"amd-smi"'
    else
        # Sum of uncorrectable errors over all RAS blocks, per GPU (PCI address)
        ecc=$( (sed -n 's#^/sys/bus/pci/devices/\([^/]*\)/ras/[^:]*_err_count:ue: *\([0-9][0-9]*\)$#\1\t\2#p' "$r" 2>/dev/null || true) |
            jq -Rn '[inputs | split("\t") | {gpu: .[0], count: (.[1] | tonumber)}]
                | group_by(.gpu) | map({gpu: .[0].gpu, count: (map(.count) | add)})')
        if [ "$(printf '%s' "${ecc:-[]}" | jq length)" -gt 0 ]; then source='"sysfs"'; fi
    fi
    jq -n --argjson visible "${visible:-null}" --argjson ecc "${ecc:-[]}" --argjson source "$source" \
        --argjson loaded "$([ -d /sys/module/amdgpu ] && echo true || echo false)" \
        '{driver_loaded: $loaded, smi_visible: $visible, ecc_source: $source, ecc_uncorrectable: $ecc}'
}

azc_commands_json() {
    tail -n +2 "$AZC_DIR/commands.tsv" | jq -Rn '[inputs | split("\t")
        | {status: .[0], exit_code: (.[1] | tonumber? // null),
           duration_s: (.[2] | rtrimstr("s") | tonumber? // null), output: .[3], command: .[4]}]'
}

azc_notes_json() {
    jq -Rn '[inputs | select(length > 0) | split("\t") | {severity: .[0], message: .[1]}]' < "$AZC_DIR/notes.tsv"
}

# azc_json_file <file>: the file if it is valid JSON, else null
azc_json_file() {
    if [ -r "$1" ] && jq -e . "$1" >/dev/null 2>&1; then jq . "$1"; else echo null; fi
}

# azc_write_facts <context: diagnostics|build> <collector name> <collector version> [options JSON] [service...]
# Run after collection: parses the collected output plus sysfs/procfs into $AZC_DIR/facts.json.
azc_write_facts() {
    local context=$1 collector=$2 collector_version=$3 options=${4:-'{}'}
    shift 4 || shift $#
    if ! command -v jq >/dev/null 2>&1; then
        azc_note WARN "jq is not installed; facts.json and the automated checks are unavailable"
        return 0
    fi
    azc_log "Structuring collected data into facts.json"
    local t="$AZC_DIR/.facts"
    rm -rf "$t"
    mkdir -p "$t"

    azc_expected_json > "$t/expected.json" 2>> "$AZC_LOG" || true
    azc_rdma_ports_json > "$t/rdma.json" 2>> "$AZC_LOG" || true
    azc_services_json "$@" > "$t/services.json" 2>> "$AZC_LOG" || true
    azc_dkms_json > "$t/dkms.json" 2>> "$AZC_LOG" || true
    azc_nvidia_json > "$t/nvidia.json" 2>> "$AZC_LOG" || true
    azc_amd_json > "$t/amd.json" 2>> "$AZC_LOG" || true
    azc_commands_json > "$t/commands.json" 2>> "$AZC_LOG" || true
    azc_notes_json > "$t/notes.json" 2>> "$AZC_LOG" || true
    azc_json_file "$AZC_COMPONENT_VERSIONS_FILE" > "$t/component_versions.json" || true
    azc_json_file "$AZC_BUILD_MANIFEST_FILE" > "$t/build_manifest.json" || true
    (awk '{print $1}' /proc/modules 2>/dev/null || true) | azc_lines_json > "$t/modules.json" || true
    (systemctl --failed --plain --no-legend 2>/dev/null || true) | awk '{print $1}' | azc_lines_json > "$t/failed.json" || true
    (
        # shellcheck disable=SC1091
        . /etc/os-release 2>/dev/null || true
        jq -n --arg id "${ID:-}" --arg version_id "${VERSION_ID:-}" --arg pretty "${PRETTY_NAME:-}" \
            --arg kernel "$(uname -r)" --arg arch "$(uname -m)" \
            '{id: $id, version_id: $version_id, pretty_name: $pretty, kernel: $kernel, arch: $arch}'
    ) > "$t/os.json" 2>> "$AZC_LOG" || true

    local root_use
    root_use=$(df -P / 2>/dev/null | awk 'NR==2 {sub("%", "", $5); print $5}' || true)
    [[ "$root_use" =~ ^[0-9]+$ ]] || root_use=null
    printf '%s' "$options" | jq . > "$t/options.json" 2>> "$AZC_LOG" || echo '{}' > "$t/options.json"

    if ! jq -n \
        --arg schema_version "$AZC_FACTS_SCHEMA_VERSION" \
        --arg context "$context" \
        --arg collector "$collector" \
        --arg collector_version "$collector_version" \
        --arg lib_version "$AZC_LIB_VERSION" \
        --arg collected_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --arg hostname "$(hostname)" \
        --arg vm_size "${AZC_VM_SIZE:-}" \
        --argjson pci_nvidia "${AZC_PCI_NVIDIA_GPUS:-0}" \
        --argjson pci_nvswitch "${AZC_PCI_NVSWITCHES:-0}" \
        --argjson pci_amd "${AZC_PCI_AMD_GPUS:-0}" \
        --argjson pci_ib "${AZC_PCI_IB_CONTROLLERS:-0}" \
        --argjson root_use "$root_use" \
        --slurpfile options "$t/options.json" \
        --slurpfile expected "$t/expected.json" \
        --slurpfile os "$t/os.json" \
        --slurpfile component_versions "$t/component_versions.json" \
        --slurpfile build_manifest "$t/build_manifest.json" \
        --slurpfile modules "$t/modules.json" \
        --slurpfile dkms "$t/dkms.json" \
        --slurpfile rdma "$t/rdma.json" \
        --slurpfile services "$t/services.json" \
        --slurpfile failed "$t/failed.json" \
        --slurpfile nvidia "$t/nvidia.json" \
        --slurpfile amd "$t/amd.json" \
        --slurpfile commands "$t/commands.json" \
        --slurpfile notes "$t/notes.json" \
        '{
            schema_version: $schema_version,
            context: $context,
            collector: {name: $collector, version: $collector_version, lib_version: $lib_version},
            collected_at: $collected_at,
            hostname: $hostname,
            options: ($options[0] // {}),
            vm: {size: (if $vm_size == "" then null else $vm_size end), source: (if $vm_size == "" then null else "imds" end)},
            expected_hardware: ($expected[0] // {known: false, gpu_vendor: null, gpu_count: null, infiniband: null, nvswitch: null}),
            pci: {nvidia_gpus: $pci_nvidia, nvswitches: $pci_nvswitch, amd_gpus: $pci_amd, infiniband_controllers: $pci_ib},
            os: ($os[0] // null),
            image: {component_versions: ($component_versions[0] // null), build_manifest: ($build_manifest[0] // null)},
            kernel_modules: ($modules[0] // []),
            dkms: ($dkms[0] // []),
            rdma: {ports: ($rdma[0] // [])},
            services: ($services[0] // []),
            failed_units: ($failed[0] // []),
            filesystems: {root_use_percent: $root_use},
            gpus: {nvidia: ($nvidia[0] // null), amd: ($amd[0] // null)},
            commands: ($commands[0] // []),
            notes: ($notes[0] // [])
        }' > "$AZC_DIR/facts.json" 2>> "$AZC_LOG"; then
        azc_log "WARNING: failed to build facts.json (see collector log)"
        rm -f "$AZC_DIR/facts.json"
    fi
    rm -rf "$t"
}
