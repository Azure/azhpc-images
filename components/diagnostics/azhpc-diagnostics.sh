#!/usr/bin/pkexec /bin/bash
# shellcheck shell=bash
#
# azhpc-diagnostics: collect a diagnostics bundle for Azure HPC/AI image support requests.
# On NVIDIA VMs it wraps nvidia-bug-report.sh and adds only what that report lacks.
# Read-only unless --gpu-diag or --nhc is given. Nothing is uploaded.

VERSION="1.0.0"
ORIG_ARGS="$*"

OUTPUT_BASE=/var/tmp
GPU_DIAG_LEVEL=0
RUN_NHC=false
RUN_BUG_REPORT=true
CMD_TIMEOUT=120

NHC_SCRIPT=/opt/azurehpc/test/azurehpc-health-checks/run-health-checks.sh
COMPONENT_VERSIONS_FILE=/opt/azurehpc/component_versions.txt
SERVICES="waagent walinuxagent sku-customizations openibd azure_persistent_rdma_naming \
nvidia-persistenced nvidia-fabricmanager nvidia-imex nvidia-dcgm rocmstartup docker \
sunrpc_tcp_settings nvme-raid"
# Services expected to stay active (excludes one-shot services and fabricmanager, checked separately)
PERSISTENT_SERVICES="waagent walinuxagent sku-customizations openibd nvidia-persistenced \
nvidia-imex nvidia-dcgm docker sunrpc_tcp_settings nvme-raid"

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Collect GPU, system, InfiniBand, MPI and image information from this VM into a
single tarball that can be attached to an Azure support request. On NVIDIA VMs
this includes a full nvidia-bug-report.sh report.

Runs as root through pkexec, which asks for authentication if you don't start
it with sudo.

By default only read-only commands are run. The VM can keep running workloads,
although collection may take a few minutes.

Options:
  -o, --output-dir DIR   Absolute path of the directory to write the tarball to
                         (default: /var/tmp)
      --gpu-diag LEVEL   Also run 'dcgmi diag -r LEVEL' (1-3) on NVIDIA GPUs.
                         Level 1 takes about a minute, levels 2 and 3 take
                         several minutes up to an hour. Stresses the GPUs; do
                         not run alongside workloads.
      --nhc              Also run Azure HPC node health checks. Takes several
                         minutes and stresses GPUs and network; do not run
                         alongside workloads.
      --no-bug-report    Skip nvidia-bug-report.sh (e.g. if it hangs)
      --timeout SECONDS  Per-command timeout (default: $CMD_TIMEOUT)
  -V, --version          Print version and exit
  -h, --help             Print this help and exit

The bundle may contain hostnames, IP/MAC addresses and hardware serial numbers.
Review it before sharing.
EOF
}

die() {
    echo "ERROR: $*" >&2
    exit 1
}

need_arg() {
    [ -n "${2:-}" ] || die "Option $1 requires an argument"
}

while [ $# -gt 0 ]; do
    case "$1" in
        -o|--output-dir) need_arg "$1" "${2:-}"; OUTPUT_BASE="$2"; shift 2 ;;
        --output-dir=*) OUTPUT_BASE="${1#*=}"; shift ;;
        --gpu-diag) need_arg "$1" "${2:-}"; GPU_DIAG_LEVEL="$2"; shift 2 ;;
        --gpu-diag=*) GPU_DIAG_LEVEL="${1#*=}"; shift ;;
        --nhc) RUN_NHC=true; shift ;;
        --no-bug-report) RUN_BUG_REPORT=false; shift ;;
        --timeout) need_arg "$1" "${2:-}"; CMD_TIMEOUT="$2"; shift 2 ;;
        --timeout=*) CMD_TIMEOUT="${1#*=}"; shift ;;
        -V|--version) echo "$VERSION"; exit 0 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
    esac
done

[[ "$GPU_DIAG_LEVEL" =~ ^[0-3]$ ]] || die "--gpu-diag must be 1, 2 or 3"
[[ "$CMD_TIMEOUT" =~ ^[1-9][0-9]*$ ]] || die "--timeout must be a positive integer"
# pkexec starts in root's home, so relative paths don't work
[[ "$OUTPUT_BASE" == /* ]] || die "--output-dir must be an absolute path"
# 'bash azhpc-diagnostics.sh' bypasses the pkexec shebang
[ "$(id -u)" -eq 0 ] || die "This script must be run as root (use sudo)"

export LC_ALL=C
export PATH="$PATH:/usr/local/sbin:/usr/sbin:/sbin:/usr/local/cuda/bin:/opt/rocm/bin"
umask 077

mkdir -p "$OUTPUT_BASE" || die "Cannot create output directory $OUTPUT_BASE"
OUTPUT_BASE=$(cd "$OUTPUT_BASE" && pwd) || die "Cannot access output directory"
START_TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ)
BUNDLE_NAME="azhpc-diagnostics-$(hostname -s 2>/dev/null || hostname)-$(date -u +%Y%m%dT%H%M%SZ)"
WORK_DIR="$OUTPUT_BASE/$BUNDLE_NAME"
TARBALL="$WORK_DIR.tar.gz"
COMMANDS="$WORK_DIR/commands.tsv"
FINDINGS="$WORK_DIR/findings.txt"
RUN_LOG="$WORK_DIR/collector.log"

mkdir -p "$WORK_DIR" || die "Cannot create $WORK_DIR"
printf 'STATUS\tEXIT\tDURATION\tOUTPUT\tCOMMAND\n' > "$COMMANDS"
: > "$FINDINGS"

####################################################################################################
# Helpers
####################################################################################################

log() {
    printf '[%s] %s\n' "$(date -u +%H:%M:%S)" "$*" | tee -a "$RUN_LOG"
}

finding() {
    printf '%-5s %s\n' "$1" "$2" >> "$FINDINGS"
}

# run_t <timeout> <output file> <command> [args...]: log output and status to commands.tsv, never abort
run_t() {
    local t="$1" rel="$2"
    shift 2
    local out="$WORK_DIR/$rel" start rc status
    if ! command -v "$1" >/dev/null 2>&1; then
        printf 'SKIPPED\t-\t0s\t%s\t%s (not installed)\n' "$rel" "$*" >> "$COMMANDS"
        return 127
    fi
    mkdir -p "$(dirname "$out")"
    printf '$ %s\n\n' "$*" >> "$out"
    start=$SECONDS
    timeout -k 10 "$t" "$@" >> "$out" 2>&1 < /dev/null
    rc=$?
    printf '\n[exit code: %s]\n\n' "$rc" >> "$out"
    case $rc in
        0) status=OK ;;
        124|137) status=TIMEOUT ;;
        *) status=FAIL ;;
    esac
    printf '%s\t%s\t%ss\t%s\t%s\n' "$status" "$rc" "$((SECONDS - start))" "$rel" \
        "$(printf '%s' "$*" | tr -s '\t\n ' ' ')" >> "$COMMANDS"
    return $rc
}

run() {
    run_t "$CMD_TIMEOUT" "$@"
}

run_sh() {
    run_t "$CMD_TIMEOUT" "$1" bash -c "$2"
}

# copy_file <destination relative to bundle> <source>
copy_file() {
    [ -f "$2" ] || return 0
    mkdir -p "$(dirname "$WORK_DIR/$1")"
    cp -L "$2" "$WORK_DIR/$1" 2>> "$RUN_LOG"
}

# copy_paths <destination dir relative to bundle> <path>... (keeps the source path)
copy_paths() {
    local dest="$WORK_DIR/$1" p
    shift
    for p in "$@"; do
        [ -e "$p" ] || continue
        mkdir -p "$dest"
        cp -a --parents "$p" "$dest" 2>> "$RUN_LOG"
    done
}

# tail_log <destination dir relative to bundle> <file> [lines]
tail_log() {
    [ -f "$2" ] || return 0
    mkdir -p "$WORK_DIR/$1"
    tail -n "${3:-50000}" "$2" > "$WORK_DIR/$1/$(basename "$2")" 2>> "$RUN_LOG"
}

# pci_devices <vendor id> <class regex>: print matching PCI addresses
pci_devices() {
    local d
    for d in /sys/bus/pci/devices/*; do
        [ "$(cat "$d/vendor" 2>/dev/null)" = "$1" ] || continue
        grep -Eq "$2" "$d/class" 2>/dev/null && basename "$d"
    done
}

count_lines() {
    if [ -z "$1" ]; then echo 0; else echo "$1" | grep -c .; fi
}

imds() {
    curl -sf --noproxy '*' --connect-timeout 2 --max-time 5 -H Metadata:true \
        "http://169.254.169.254/metadata/instance/$1?api-version=2021-02-01$2" 2>/dev/null
}

has_ib_devices() {
    compgen -G '/sys/class/infiniband/*' >/dev/null
}

####################################################################################################
# Collection
####################################################################################################

collect_nvidia_bug_report() {
    [ "$NVIDIA_GPU_COUNT" -gt 0 ] && [ "$RUN_BUG_REPORT" = true ] || return
    if ! command -v nvidia-bug-report.sh >/dev/null 2>&1; then
        finding WARN "nvidia-bug-report.sh is not installed"
        return
    fi
    log "Running nvidia-bug-report.sh (this can take a few minutes)"
    mkdir -p "$WORK_DIR/nvidia"
    # The report writes temporary files to the working directory
    run_t 900 nvidia/nvidia-bug-report.console.txt bash -c \
        "cd '$WORK_DIR/nvidia' && nvidia-bug-report.sh --output-file '$WORK_DIR/nvidia/nvidia-bug-report.log'"
}

collect_image() {
    log "Collecting image and VM metadata"
    mkdir -p "$WORK_DIR/image"
    copy_file image/component_versions.json "$COMPONENT_VERSIONS_FILE"
    copy_file image/os-release.txt /etc/os-release

    local compute
    compute=$(imds compute)
    if [ -n "$compute" ]; then
        if command -v jq >/dev/null 2>&1; then
            # Drop tags, subscription and similar
            echo "$compute" | jq '{vmId, vmSize, name, location, zone, placementGroupId,
                vmScaleSetName, priority, osType, securityProfile,
                imageReference: .storageProfile.imageReference}' \
                > "$WORK_DIR/image/imds-compute.json" 2>> "$RUN_LOG"
        else
            echo "$compute" | grep -oE '"(vmId|vmSize|location)":"[^"]*"' \
                > "$WORK_DIR/image/imds-compute.txt"
        fi
        VM_SIZE=$(imds compute/vmSize '&format=text')
    else
        finding INFO "Azure Instance Metadata Service is not reachable (expected on bare-metal nodes)"
    fi

    # KVP pool 3 has host-provided values such as the physical host name
    if [ -r /var/lib/hyperv/.kvp_pool_3 ]; then
        tr -s '\0' '\n' < /var/lib/hyperv/.kvp_pool_3 > "$WORK_DIR/image/kvp_pool_3.txt"
    fi
}

collect_system() {
    log "Collecting OS and hardware information"
    run system/uname.txt uname -a
    run system/uptime.txt uptime
    run system/lscpu.txt lscpu
    run system/numactl.txt numactl -H
    run system/free.txt free -h
    run system/df.txt df -hT
    run system/lsblk.txt lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT,MODEL
    run_sh system/ulimit.txt 'ulimit -a'
    copy_paths system/config /etc/security/limits.conf /etc/security/limits.d /etc/modprobe.d
    run system/sysctl.txt sysctl -a
    run system/dkms-status.txt dkms status
    run system/journal-errors.txt journalctl -b -p err --no-pager -o short-iso
    run system/journal-previous-boot-errors.txt journalctl -b -1 -p err --no-pager -o short-iso
    run system/systemctl-failed.txt systemctl --failed --no-pager
    run system/getenforce.txt getenforce

    if command -v dpkg-query >/dev/null 2>&1; then
        run system/packages.txt dpkg-query -W -f '${Status}\t${Package}\t${Version}\t${Architecture}\n'
        run system/packages-held.txt apt-mark showhold
    else
        run_sh system/packages.txt "rpm -qa --qf '%{NAME}\t%{VERSION}-%{RELEASE}\t%{ARCH}\n' | sort"
        run system/packages-held.txt dnf versionlock list
        copy_file system/dnf.conf /etc/dnf/dnf.conf
    fi
}

collect_services() {
    log "Collecting service status"
    local svc
    for svc in $SERVICES; do
        systemctl cat "$svc.service" >/dev/null 2>&1 || continue
        # exit 3 = not running, normal for one-shot units
        run_sh "services/$svc.txt" "systemctl status --no-pager -l $svc.service || [ \$? -eq 3 ]"
        run "services/$svc.txt" journalctl -b -u "$svc.service" --no-pager -n 500 -o short-iso
    done
}

collect_logs() {
    log "Collecting log files"
    local f
    for f in /var/log/waagent.log /var/log/cloud-init.log /var/log/cloud-init-output.log \
             /var/log/syslog /var/log/messages; do
        tail_log logs "$f"
    done
    # VM extension logs
    if [ -d /var/log/azure ]; then
        mkdir -p "$WORK_DIR/logs"
        find /var/log/azure -type f -size -20M -exec cp --parents {} "$WORK_DIR/logs" \; 2>> "$RUN_LOG"
    fi
}

collect_network() {
    log "Collecting network and InfiniBand information"
    run network/ip-addr.txt ip addr
    run network/ip-link-stats.txt ip -s link
    run network/ip-route.txt ip route
    run_sh network/ethtool.txt 'for i in /sys/class/net/*; do i=${i##*/}; [ "$i" = lo ] && continue; echo "== $i"; ethtool -i "$i" 2>&1; echo; done'
    copy_file network/waagent.conf /etc/waagent.conf

    if [ "$IB_HCA_COUNT" -eq 0 ] && ! has_ib_devices; then
        return
    fi
    # ibstat and fabric/mlxlink dumps are in nvidia-bug-report.sh
    run infiniband/ofed_info.txt ofed_info -s
    run infiniband/ibv_devinfo.txt ibv_devinfo -v
    run infiniband/ibdev2netdev.txt ibdev2netdev -v
    if has_ib_devices; then
        run_sh infiniband/sysfs.txt 'for d in /sys/class/infiniband/*; do
            grep -H . "$d"/fw_ver "$d"/board_id "$d"/hca_type "$d"/node_guid 2>/dev/null
            for p in "$d"/ports/*; do
                grep -H . "$p"/state "$p"/phys_state "$p"/rate "$p"/link_layer "$p"/lid "$p"/sm_lid "$p"/pkeys/0 "$p"/pkeys/1 2>/dev/null
            done
        done; true'
        run_sh infiniband/port-counters.txt 'grep -H . /sys/class/infiniband/*/ports/*/counters/* /sys/class/infiniband/*/ports/*/hw_counters/* 2>/dev/null; true'
    fi
}

collect_nvidia() {
    [ "$NVIDIA_GPU_COUNT" -gt 0 ] || return
    log "Collecting additional NVIDIA GPU information"
    # Used by the automated checks; topo -m isn't in nvidia-bug-report.sh
    run nvidia/nvidia-smi-query.txt nvidia-smi --format=csv \
        --query-gpu=index,pci.bus_id,name,serial,uuid,driver_version,vbios_version,persistence_mode,ecc.errors.uncorrected.volatile.total,temperature.gpu
    run nvidia/nvidia-smi-remapped-rows.txt nvidia-smi --format=csv \
        --query-gpu=index,pci.bus_id,remapped_rows.pending,remapped_rows.failure
    run nvidia/nvidia-smi-topo.txt nvidia-smi topo -m

    if [ "$GPU_DIAG_LEVEL" -gt 0 ]; then
        local t
        case $GPU_DIAG_LEVEL in 1) t=600 ;; 2) t=1800 ;; *) t=5400 ;; esac
        log "Running dcgmi diag -r $GPU_DIAG_LEVEL"
        # dcgmi writes its logs to the working directory
        run_t "$t" "nvidia/dcgmi-diag-r$GPU_DIAG_LEVEL.txt" \
            bash -c "cd '$WORK_DIR/nvidia' && dcgmi diag -r $GPU_DIAG_LEVEL"
    fi
}

collect_amd() {
    [ "$AMD_GPU_COUNT" -gt 0 ] || return
    log "Collecting AMD GPU information"
    copy_file amd/rocm-version.txt /opt/rocm/.info/version
    run amd/dmesg.txt dmesg -T
    run amd/amd-smi-version.txt amd-smi version
    run amd/amd-smi-list.txt amd-smi list
    run amd/amd-smi-static.txt amd-smi static
    run amd/amd-smi-firmware.txt amd-smi firmware
    run amd/amd-smi-metric.txt amd-smi metric
    run amd/amd-smi-xgmi.txt amd-smi xgmi
    run amd/rocminfo.txt rocminfo
}

collect_software() {
    log "Collecting MPI, NCCL and container configuration"
    run software/opt.txt ls -la /opt /opt/azurehpc /opt/microsoft
    run_t 60 software/modules.txt bash -lc 'module avail 2>&1'
    copy_file software/nccl.conf /etc/nccl.conf
    run_sh software/ldconfig-comm-libs.txt "ldconfig -p | grep -Ei 'nccl|rccl|sharp|ucx|ucc|gdrapi|libfabric'"
    run_t 30 software/docker-info.txt docker info
    copy_file software/docker-daemon.json /etc/docker/daemon.json
}

run_health_checks() {
    [ "$RUN_NHC" = true ] || return
    if [ ! -x "$NHC_SCRIPT" ]; then
        finding INFO "--nhc was requested but $NHC_SCRIPT is not installed on this image"
        return
    fi
    log "Running Azure HPC node health checks (this can take several minutes)"
    mkdir -p "$WORK_DIR/nhc"
    run_t 3600 nhc/run-health-checks.txt "$NHC_SCRIPT" -a -o "$WORK_DIR/nhc/health.log"
}

####################################################################################################
# Automated checks: quick hints for common issues, based on the collected data
####################################################################################################

analyze() {
    log "Checking for common issues"

    local image_kernel
    image_kernel=$(sed -n 's/.*"KERNEL": *"\([^"]*\)".*/\1/p' "$COMPONENT_VERSIONS_FILE" 2>/dev/null | head -1)
    if [ -n "$image_kernel" ] && [ "$image_kernel" != "$(uname -r)" ]; then
        finding WARN "Running kernel $(uname -r) differs from the image kernel $image_kernel. Kernel modules shipped with the image (GPU driver, DOCA/OFED, Lustre) may not be built for this kernel."
    fi

    local root_use
    root_use=$(df -P / 2>/dev/null | awk 'NR==2 {sub("%", "", $5); print $5}')
    if [ -n "$root_use" ] && [ "$root_use" -ge 90 ]; then
        finding WARN "Root file system is ${root_use}% full"
    fi

    local failed
    failed=$(systemctl --failed --plain --no-legend 2>/dev/null | awk '{print $1}' | xargs)
    [ -n "$failed" ] && finding WARN "Failed systemd units: $failed"

    local svc
    for svc in $PERSISTENT_SERVICES; do
        if systemctl is-enabled --quiet "$svc.service" 2>/dev/null && \
           ! systemctl is-active --quiet "$svc.service" 2>/dev/null; then
            finding WARN "Service $svc is enabled but not active (see services/$svc.txt)"
        fi
    done
    if [ "$NVSWITCH_COUNT" -gt 0 ] && ! systemctl is-active --quiet nvidia-fabricmanager.service 2>/dev/null; then
        finding ERROR "nvidia-fabricmanager is not active but $NVSWITCH_COUNT NVSwitch(es) are present; CUDA and NCCL will fail on this VM"
    fi

    # InfiniBand
    local ib_ports=0 port state
    for port in /sys/class/infiniband/*/ports/*; do
        [ "$(cat "$port/link_layer" 2>/dev/null)" = InfiniBand ] || continue
        ib_ports=$((ib_ports + 1))
        state=$(cat "$port/state" 2>/dev/null)
        case $state in
            *ACTIVE*) ;;
            *) finding WARN "InfiniBand port ${port#/sys/class/infiniband/} is ${state#*: }" ;;
        esac
    done
    if [ "$IB_HCA_COUNT" -gt 0 ] && [ "$ib_ports" -eq 0 ]; then
        finding ERROR "$IB_HCA_COUNT InfiniBand HCA(s) on the PCI bus but no InfiniBand ports registered (is the mlx5_ib driver loaded?)"
    fi

    # NVIDIA
    if [ "$NVIDIA_GPU_COUNT" -gt 0 ]; then
        if [ ! -e /proc/driver/nvidia/version ]; then
            finding ERROR "NVIDIA kernel driver is not loaded ($NVIDIA_GPU_COUNT NVIDIA GPU(s) on the PCI bus)"
        else
            local smi_count
            smi_count=$(grep -cE '^[0-9]+, ' "$WORK_DIR/nvidia/nvidia-smi-query.txt" 2>/dev/null)
            if [ "${smi_count:-0}" -lt "$NVIDIA_GPU_COUNT" ]; then
                finding ERROR "nvidia-smi lists ${smi_count:-0} of $NVIDIA_GPU_COUNT NVIDIA GPU(s) found on the PCI bus"
            fi
        fi

        local xids
        xids=$(dmesg 2>/dev/null | grep -oE 'NVRM: Xid \([^)]*\): [0-9]+' |
            awk '{print $NF}' | sort -n | uniq -c | awk '{printf "%s%s (x%s)", sep, $2, $1; sep=", "}')
        [ -n "$xids" ] && finding WARN "NVIDIA Xid errors in kernel log: $xids"

        local ecc
        ecc=$(awk -F', ' '$9 ~ /^[0-9]+$/ && $9 > 0 {printf "%sGPU %s (%s): %s", sep, $1, $2, $9; sep="; "}' \
            "$WORK_DIR/nvidia/nvidia-smi-query.txt" 2>/dev/null)
        [ -n "$ecc" ] && finding WARN "Uncorrectable volatile ECC errors: $ecc"

        local remap
        remap=$(awk -F', ' '$3 ~ /Yes/ || $4 ~ /Yes/ {printf "%sGPU %s (%s): pending=%s failure=%s", sep, $1, $2, $3, $4; sep="; "}' \
            "$WORK_DIR/nvidia/nvidia-smi-remapped-rows.txt" 2>/dev/null)
        [ -n "$remap" ] && finding WARN "GPU row remapping pending or failed (pending needs a GPU reset or reboot): $remap"

        if [ "$ib_ports" -gt 0 ] && [ ! -d /sys/module/nvidia_peermem ]; then
            finding WARN "nvidia_peermem module is not loaded; GPUDirect RDMA over InfiniBand is unavailable"
        fi
    fi

    # AMD
    if [ "$AMD_GPU_COUNT" -gt 0 ]; then
        if [ ! -d /sys/module/amdgpu ]; then
            finding ERROR "amdgpu kernel driver is not loaded ($AMD_GPU_COUNT AMD GPU(s) on the PCI bus)"
        elif [ -s "$WORK_DIR/amd/amd-smi-list.txt" ]; then
            local amd_count
            amd_count=$(grep -c '^GPU: ' "$WORK_DIR/amd/amd-smi-list.txt")
            if [ "$amd_count" -lt "$AMD_GPU_COUNT" ]; then
                finding ERROR "amd-smi lists $amd_count of $AMD_GPU_COUNT AMD GPU(s) found on the PCI bus"
            fi
        fi

        local amd_ecc
        amd_ecc=$(awk '/^GPU: / {g = $2}
            /TOTAL_UNCORRECTABLE_COUNT:/ && $2 ~ /^[0-9]+$/ && $2 > 0 {printf "%sGPU %s: %s", sep, g, $2; sep="; "}' \
            "$WORK_DIR/amd/amd-smi-metric.txt" 2>/dev/null)
        [ -n "$amd_ecc" ] && finding WARN "Uncorrectable ECC errors: $amd_ecc"
    fi

    local timeouts
    timeouts=$(awk -F'\t' '$1 == "TIMEOUT" {printf "%s%s", sep, $5; sep="; "}' "$COMMANDS")
    [ -n "$timeouts" ] && finding WARN "Commands timed out (possible hung device or driver): $timeouts"
}

####################################################################################################
# Main
####################################################################################################

finalize() {
    cat > "$WORK_DIR/info.txt" <<EOF
azhpc-diagnostics version: $VERSION
Options: ${ORIG_ARGS:-<none>}
Start time (UTC): $START_TIME
End time (UTC): $(date -u +%Y-%m-%dT%H:%M:%SZ)
Hostname: $(hostname)
VM size: ${VM_SIZE:-unknown}
Kernel: $(uname -r)
NVIDIA GPUs on PCI bus: $NVIDIA_GPU_COUNT
NVSwitches on PCI bus: $NVSWITCH_COUNT
AMD GPUs on PCI bus: $AMD_GPU_COUNT
InfiniBand HCAs on PCI bus: $IB_HCA_COUNT
EOF
    FINDINGS_TEXT=$(cat "$FINDINGS")
    if tar -C "$OUTPUT_BASE" -czf "$TARBALL" "$BUNDLE_NAME" 2>> "$RUN_LOG"; then
        rm -rf "$WORK_DIR"
        return 0
    fi
    echo "ERROR: failed to create $TARBALL; uncompressed results are in $WORK_DIR" >&2
    return 1
}

on_interrupt() {
    trap - INT TERM
    log "Interrupted; packaging what has been collected so far"
    finding WARN "Collection was interrupted; bundle is incomplete"
    finalize && echo "Partial diagnostics bundle: $TARBALL"
    exit 130
}
trap on_interrupt INT TERM

cat <<EOF
Azure HPC diagnostics collector $VERSION
Collecting diagnostics into $WORK_DIR
Nothing is uploaded. The bundle may contain hostnames, IP/MAC addresses and
hardware serial numbers; review it before sharing.

EOF

NVIDIA_GPU_COUNT=$(count_lines "$(pci_devices 0x10de '^0x03')")
AMD_GPU_COUNT=$(count_lines "$(pci_devices 0x1002 '^0x(03|12)')")
IB_HCA_COUNT=$(count_lines "$(pci_devices 0x15b3 '^0x0207')")
NVSWITCH_COUNT=$(count_lines "$(pci_devices 0x10de '^0x0680')")
log "Detected $NVIDIA_GPU_COUNT NVIDIA GPU(s), $NVSWITCH_COUNT NVSwitch(es), $AMD_GPU_COUNT AMD GPU(s), $IB_HCA_COUNT InfiniBand HCA(s) on the PCI bus"

collect_nvidia_bug_report
collect_image
collect_system
collect_services
collect_logs
collect_network
collect_software
collect_amd
collect_nvidia
run_health_checks
analyze

finalize || exit 1

echo
echo "==== Findings (automated hints, not exhaustive) ===="
if [ -n "$FINDINGS_TEXT" ]; then
    echo "$FINDINGS_TEXT"
else
    echo "No issues detected by the automated checks."
fi
echo
echo "Diagnostics bundle: $TARBALL"
echo "Attach this file to your Azure support request."
