# shellcheck shell=bash
#
# azhpc-collect-lib: data collection shared by azhpc-diagnostics (support bundles) and
# packer/scripts/collect_build_evidence.sh (image build evidence). Source it; it only defines
# functions and variables.
#
# Collection comes in two tiers:
#   general   azc_collect_os, _platform, _kernel, _software_state, _services, _logs, _network,
#             _hpc_stack and _image: software state and generic hardware inventory that can be
#             collected on any VM, including the general-purpose VMs that image builds may run on.
#   hardware  azc_collect_rdma, _nvidia and _amd: need InfiniBand NICs or GPUs. Only
#             azhpc-diagnostics runs them; image build evidence doesn't.
#
# Collection is separate from structuring and analysis: the azc_collect_* functions only write
# raw command output, azhpc-diagnostics-facts.py turns it into facts.json, and
# azhpc-diagnostics-analyze.py checks facts.json. Neither Python script runs commands, so both
# can be re-run offline on a diagnostics bundle or on build evidence.
#
# All functions are safe under 'set -euo pipefail'. Failing commands are recorded in
# commands.tsv and never abort the caller.
#
# Layout of $AZC_DIR:
#   commands.tsv  status, exit code, duration, output file and command line of every command
#   notes.tsv     collector notes (severity, message), reported as findings by the analyzer
#   tiers.txt     collection tiers that ran (general, hardware)
#   facts.json    structured facts; findings.json and findings.txt: results of the analyzer
#   system/ hardware/ network/ infiniband/ services/ logs/ software/ image/ nvidia/ amd/

AZC_LIB_VERSION="1.0.0"
AZC_LIB_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
AZC_FACTS_SCRIPT="$AZC_LIB_DIR/azhpc-diagnostics-facts.py"
AZC_ANALYZER="$AZC_LIB_DIR/azhpc-diagnostics-analyze.py"
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
    touch "$AZC_DIR/notes.tsv" "$AZC_DIR/tiers.txt"
}

azc_log() {
    printf '[%s] %s\n' "$(date -u +%H:%M:%S)" "$*" | tee -a "$AZC_LOG"
}

# azc_note <ERROR|WARN|INFO> <message>
azc_note() {
    printf '%s\t%s\n' "$1" "$(printf '%s' "$2" | tr -s '\t\n' ' ')" >> "$AZC_DIR/notes.tsv"
}

# azc_tier <general|hardware>: records that a tier ran, so facts.json says what was collected
azc_tier() {
    grep -qx "$1" "$AZC_DIR/tiers.txt" 2>/dev/null || echo "$1" >> "$AZC_DIR/tiers.txt"
}

# azc_python: prints the Python 3 interpreter. EL8 images may only have platform-python.
azc_python() {
    local p
    for p in python3 /usr/libexec/platform-python; do
        # command -v also prints non-executable matches when there is no executable one
        p=$(command -v "$p" 2>/dev/null) || continue
        if [ -x "$p" ]; then
            echo "$p"
            return 0
        fi
    done
    return 1
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
# Intended vs. observed hardware (decides which hardware-tier collection runs)
####################################################################################################

# azc_detect: sets AZC_VM_SIZE and AZC_EXPECT_GPU_VENDOR (intended hardware of the VM size, see
# SKU_HARDWARE in azhpc-diagnostics-facts.py) and AZC_PCI_NVIDIA_GPUS/AZC_PCI_AMD_GPUS (observed)
azc_detect() {
    local py
    AZC_VM_SIZE=$(azc_imds compute/vmSize '&format=text')
    AZC_EXPECT_GPU_VENDOR=unknown
    if [ -n "$AZC_VM_SIZE" ] && py=$(azc_python); then
        AZC_EXPECT_GPU_VENDOR=$("$py" "$AZC_FACTS_SCRIPT" sku-hardware --field gpu_vendor "$AZC_VM_SIZE" 2>> "$AZC_LOG") ||
            AZC_EXPECT_GPU_VENDOR=unknown
    fi
    AZC_PCI_NVIDIA_GPUS=$(azc_pci_count '^0x10de$' '^0x03')
    AZC_PCI_AMD_GPUS=$(azc_pci_count '^0x1002$' '^0x(03|12)')
    mkdir -p "$AZC_DIR/image"
    printf '%s\n' "$AZC_VM_SIZE" > "$AZC_DIR/image/vm-size.txt"
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
# General tier: any VM, no GPU or InfiniBand needed
####################################################################################################

azc_collect_image() {
    azc_tier general
    azc_log "Collecting image information"
    azc_copy_file image/component_versions.json "$AZC_COMPONENT_VERSIONS_FILE"
    azc_copy_file image/build-manifest.json "$AZC_BUILD_MANIFEST_FILE"
}

azc_collect_os() {
    azc_tier general
    azc_log "Collecting OS information"
    azc_copy_file system/os-release /etc/os-release
    azc_run system/hostname.txt hostname
    azc_run system/uname.txt uname -a
    azc_run system/kernel-release.txt uname -r
    azc_run system/machine.txt uname -m
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

# Generic inventory: works on any VM, and shows which devices are visible on the bus
azc_collect_platform() {
    azc_tier general
    azc_log "Collecting CPU and PCI inventory"
    azc_run hardware/lscpu.txt lscpu
    azc_run hardware/numactl.txt numactl -H
    azc_run hardware/lspci.txt lspci -nn
    azc_run hardware/lspci-tree.txt lspci -tvnn
    azc_run hardware/lspci-verbose.txt lspci -vvv -nn
    azc_run hardware/dmidecode.txt dmidecode
    # "<address> <vendor> <device> <class>" per PCI function, without depending on pciutils
    azc_run_sh hardware/pci-devices.txt 'for d in /sys/bus/pci/devices/*; do
        [ -r "$d/class" ] || continue
        echo "${d##*/} $(cat "$d/vendor") $(cat "$d/device") $(cat "$d/class")"
    done; true'
}

azc_collect_kernel() {
    azc_tier general
    azc_log "Collecting kernel modules, DKMS and kernel log"
    azc_run system/lsmod.txt lsmod
    azc_run system/dkms-status.txt dkms status
    azc_run system/dmesg.txt dmesg -T
    azc_copy_file system/nvidia-driver-version.txt /proc/driver/nvidia/version
}

azc_collect_software_state() {
    azc_tier general
    azc_log "Collecting packages and systemd state"
    azc_run system/journal-errors.txt journalctl -b -p err --no-pager -o short-iso
    azc_run system/journal-previous-boot-errors.txt journalctl -b -1 -p err --no-pager -o short-iso
    azc_run system/systemctl-failed.txt systemctl --failed --no-pager --plain --no-legend
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
    azc_tier general
    azc_log "Collecting service status"
    local svc units=()
    for svc in "$@"; do
        units+=("$svc.service")
        systemctl cat "$svc.service" >/dev/null 2>&1 || continue
        # exit 3 = not running, normal for one-shot units
        azc_run_sh "services/$svc.txt" "systemctl status --no-pager -l $svc.service || [ \$? -eq 3 ]"
        azc_run "services/$svc.txt" journalctl -b -u "$svc.service" --no-pager -n 500 -o short-iso
    done
    [ ${#units[@]} -gt 0 ] || return 0
    azc_run services/states.txt systemctl show -p Id -p LoadState -p UnitFileState -p ActiveState -p SubState "${units[@]}"
}

azc_collect_logs() {
    azc_tier general
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

azc_collect_network() {
    azc_tier general
    azc_log "Collecting network configuration"
    azc_run network/ip-addr.txt ip addr
    azc_run network/ip-link-stats.txt ip -s link
    azc_run network/ip-route.txt ip route
    azc_run_sh network/ethtool.txt 'for i in /sys/class/net/*; do i=${i##*/}; [ "$i" = lo ] && continue; echo "== $i"; ethtool -i "$i" 2>&1; echo; done'
    azc_run_sh network/ethtool-stats.txt 'for i in /sys/class/net/*; do i=${i##*/}; [ "$i" = lo ] && continue; echo "== $i"; ethtool -S "$i" 2>&1; echo; done'
    azc_copy_file network/waagent.conf /etc/waagent.conf
}

azc_collect_hpc_stack() {
    azc_tier general
    azc_log "Collecting MPI, NCCL, OFED and container configuration"
    azc_run software/opt.txt ls -la /opt /opt/azurehpc /opt/microsoft
    azc_run_t 60 software/modules.txt bash -lc 'module avail 2>&1'
    azc_copy_file software/nccl.conf /etc/nccl.conf
    azc_run_sh software/ldconfig-comm-libs.txt "ldconfig -p | grep -Ei 'nccl|rccl|sharp|ucx|ucc|gdrapi|libfabric'"
    azc_run software/ofed_info.txt ofed_info -s
    azc_run_t 30 software/docker-info.txt docker info
    azc_copy_file software/docker-daemon.json /etc/docker/daemon.json
}

####################################################################################################
# Hardware tier: InfiniBand NICs and GPUs (azhpc-diagnostics only)
####################################################################################################

# Runs whatever the GPU vendor and whatever is on the PCI bus: GPU vendor reports don't cover
# every NIC (or exist on every platform), and a missing device is itself worth reporting.
azc_collect_rdma() {
    azc_tier hardware
    azc_log "Collecting RDMA and InfiniBand information"
    azc_run network/rdma-link.txt rdma link
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

# Read-only GPU queries. Their output is parsed into facts.json.
azc_collect_nvidia() {
    azc_tier hardware
    azc_log "Collecting NVIDIA GPU information"
    azc_run nvidia/nvidia-smi-query.txt nvidia-smi --format=csv \
        --query-gpu=index,pci.bus_id,name,serial,uuid,driver_version,vbios_version,persistence_mode,ecc.errors.uncorrected.volatile.total,temperature.gpu
    azc_run nvidia/nvidia-smi-remapped-rows.txt nvidia-smi --format=csv \
        --query-gpu=index,pci.bus_id,remapped_rows.pending,remapped_rows.failure
    azc_run nvidia/nvidia-smi-topo.txt nvidia-smi topo -m
}

azc_collect_amd() {
    azc_tier hardware
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
# Structuring and analysis (Python; read only what was collected)
####################################################################################################

# azc_write_facts <context: diagnostics|build> <collector name> <collector version> [KEY=VALUE]...
# Writes $AZC_DIR/facts.json. KEY=VALUE pairs are recorded as collection options.
azc_write_facts() {
    local context=$1 collector=$2 collector_version=$3 opt py
    shift 3
    local options=()
    for opt in "$@"; do
        options+=(--option "$opt")
    done
    if ! py=$(azc_python); then
        azc_note WARN "Python 3 is not installed; facts.json and the automated checks are unavailable"
        return 0
    fi
    azc_log "Structuring collected data into facts.json"
    "$py" "$AZC_FACTS_SCRIPT" facts "$AZC_DIR" --context "$context" --collector "$collector" \
        --collector-version "$collector_version" --lib-version "$AZC_LIB_VERSION" \
        ${options[@]+"${options[@]}"} >> "$AZC_LOG" 2>&1 ||
        azc_log "WARNING: failed to build facts.json (see collector log)"
}

# azc_analyze: runs the automated checks over $AZC_DIR/facts.json into findings.json/findings.txt
azc_analyze() {
    local py
    [ -f "$AZC_DIR/facts.json" ] || return 0
    py=$(azc_python) || return 0
    azc_log "Checking for common issues"
    "$py" "$AZC_ANALYZER" "$AZC_DIR" > /dev/null 2>> "$AZC_LOG" ||
        azc_log "WARNING: automated checks failed (see collector log)"
}
