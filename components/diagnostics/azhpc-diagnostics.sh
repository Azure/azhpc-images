#!/usr/bin/pkexec /bin/bash
# shellcheck shell=bash
#
# azhpc-diagnostics: collect a diagnostics bundle for Azure HPC/AI image support requests.
#
# Three separate steps:
#   1. collection: raw command output, GPU- and NIC-agnostic (azhpc-collect-lib.sh, shared with
#      the image build evidence), plus vendor GPU data and nvidia-bug-report.sh on NVIDIA VMs
#   2. structuring: facts.json (schema/facts.schema.json)
#   3. analysis: azhpc-diagnostics-analyze.sh reads facts.json only and writes findings
# Read-only unless --gpu-diag or --nhc is given. Nothing is uploaded.

VERSION="1.0.0"
ORIG_ARGS="$*"

OUTPUT_BASE=/var/tmp
GPU_DIAG_LEVEL=0
RUN_NHC=false
RUN_BUG_REPORT=true
CMD_TIMEOUT=120

NHC_SCRIPT=/opt/azurehpc/test/azurehpc-health-checks/run-health-checks.sh

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Collect GPU, system, network/InfiniBand, MPI and image information from this VM
into a single tarball that can be attached to an Azure support request. On
NVIDIA VMs this includes a full nvidia-bug-report.sh report.

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

# Resolves the /usr/sbin/azhpc-diagnostics link to the install directory
SCRIPT_DIR=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
ANALYZER="$SCRIPT_DIR/azhpc-diagnostics-analyze.sh"
# shellcheck source-path=SCRIPTDIR source=azhpc-collect-lib.sh
. "$SCRIPT_DIR/azhpc-collect-lib.sh" || die "Cannot load $SCRIPT_DIR/azhpc-collect-lib.sh"

export LC_ALL=C
export PATH="$PATH:/usr/local/sbin:/usr/sbin:/sbin:/usr/local/cuda/bin:/opt/rocm/bin"
umask 077

mkdir -p "$OUTPUT_BASE" || die "Cannot create output directory $OUTPUT_BASE"
OUTPUT_BASE=$(cd "$OUTPUT_BASE" && pwd) || die "Cannot access output directory"
START_TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ)
BUNDLE_NAME="azhpc-diagnostics-$(hostname -s 2>/dev/null || hostname)-$(date -u +%Y%m%dT%H%M%SZ)"
WORK_DIR="$OUTPUT_BASE/$BUNDLE_NAME"
TARBALL="$WORK_DIR.tar.gz"
FINDINGS_TEXT=""

mkdir -p "$WORK_DIR" || die "Cannot create $WORK_DIR"
AZC_TIMEOUT=$CMD_TIMEOUT
azc_init "$WORK_DIR" "$WORK_DIR/collector.log"

####################################################################################################
# Diagnostics-only collection (the rest is in azhpc-collect-lib.sh)
####################################################################################################

collect_nvidia_bug_report() {
    azc_want_nvidia && [ "$RUN_BUG_REPORT" = true ] || return 0
    if ! command -v nvidia-bug-report.sh >/dev/null 2>&1; then
        azc_note WARN "nvidia-bug-report.sh is not installed"
        return 0
    fi
    azc_log "Running nvidia-bug-report.sh (this can take a few minutes)"
    mkdir -p "$WORK_DIR/nvidia"
    # The report writes temporary files to the working directory
    azc_run_t 900 nvidia/nvidia-bug-report.console.txt bash -c \
        "cd '$WORK_DIR/nvidia' && nvidia-bug-report.sh --output-file '$WORK_DIR/nvidia/nvidia-bug-report.log'"
}

collect_vm_metadata() {
    azc_log "Collecting VM metadata"
    mkdir -p "$WORK_DIR/image"
    local compute
    compute=$(azc_imds compute)
    if [ -n "$compute" ]; then
        if command -v jq >/dev/null 2>&1; then
            # Drop tags, subscription and similar
            echo "$compute" | jq '{vmId, vmSize, name, location, zone, placementGroupId,
                vmScaleSetName, priority, osType, securityProfile,
                imageReference: .storageProfile.imageReference}' \
                > "$WORK_DIR/image/imds-compute.json" 2>> "$AZC_LOG"
        else
            echo "$compute" | grep -oE '"(vmId|vmSize|location)":"[^"]*"' \
                > "$WORK_DIR/image/imds-compute.txt"
        fi
    fi

    # KVP pool 3 has host-provided values such as the physical host name
    if [ -r /var/lib/hyperv/.kvp_pool_3 ]; then
        tr -s '\0' '\n' < /var/lib/hyperv/.kvp_pool_3 > "$WORK_DIR/image/kvp_pool_3.txt"
    fi
}

run_dcgm_diag() {
    [ "$GPU_DIAG_LEVEL" -gt 0 ] || return 0
    if ! azc_want_nvidia; then
        azc_note INFO "--gpu-diag was requested but this VM has no NVIDIA GPUs"
        return 0
    fi
    local t
    case $GPU_DIAG_LEVEL in 1) t=600 ;; 2) t=1800 ;; *) t=5400 ;; esac
    azc_log "Running dcgmi diag -r $GPU_DIAG_LEVEL"
    mkdir -p "$WORK_DIR/nvidia"
    # dcgmi writes its logs to the working directory
    azc_run_t "$t" "nvidia/dcgmi-diag-r$GPU_DIAG_LEVEL.txt" \
        bash -c "cd '$WORK_DIR/nvidia' && dcgmi diag -r $GPU_DIAG_LEVEL"
}

run_health_checks() {
    [ "$RUN_NHC" = true ] || return 0
    if [ ! -x "$NHC_SCRIPT" ]; then
        azc_note INFO "--nhc was requested but $NHC_SCRIPT is not installed on this image"
        return 0
    fi
    azc_log "Running Azure HPC node health checks (this can take several minutes)"
    mkdir -p "$WORK_DIR/nhc"
    azc_run_t 3600 nhc/run-health-checks.txt "$NHC_SCRIPT" -a -o "$WORK_DIR/nhc/health.log"
}

####################################################################################################
# Structuring and analysis
####################################################################################################

structure_and_analyze() {
    # shellcheck disable=SC2086
    azc_write_facts diagnostics azhpc-diagnostics "$VERSION" \
        "{\"gpu_diag_level\": $GPU_DIAG_LEVEL, \"nhc\": $RUN_NHC, \"bug_report\": $RUN_BUG_REPORT, \"timeout_s\": $CMD_TIMEOUT}" \
        $AZC_SERVICES
    if [ -f "$WORK_DIR/facts.json" ] && [ -f "$ANALYZER" ]; then
        azc_log "Checking for common issues"
        bash "$ANALYZER" "$WORK_DIR" > /dev/null 2>> "$AZC_LOG" ||
            azc_log "WARNING: automated checks failed (see collector log)"
    fi
    if [ -f "$WORK_DIR/findings.txt" ]; then
        FINDINGS_TEXT=$(cat "$WORK_DIR/findings.txt")
    else
        FINDINGS_TEXT=$(awk -F'\t' '{printf "%-5s %s\n", $1, $2}' "$WORK_DIR/notes.tsv"
            echo "INFO  Automated checks are unavailable (see collector.log)")
    fi
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
VM size: ${AZC_VM_SIZE:-unknown}
Kernel: $(uname -r)
Intended hardware for the VM size: GPU vendor ${AZC_EXPECT_GPU_VENDOR:-unknown}, GPUs ${AZC_EXPECT_GPU_COUNT:--}, InfiniBand ${AZC_EXPECT_IB:-unknown}, NVSwitch ${AZC_EXPECT_NVSWITCH:-unknown}
NVIDIA GPUs on PCI bus: ${AZC_PCI_NVIDIA_GPUS:-0}
NVSwitches on PCI bus: ${AZC_PCI_NVSWITCHES:-0}
AMD GPUs on PCI bus: ${AZC_PCI_AMD_GPUS:-0}
InfiniBand controllers on PCI bus: ${AZC_PCI_IB_CONTROLLERS:-0}
EOF
    if tar -C "$OUTPUT_BASE" -czf "$TARBALL" "$BUNDLE_NAME" 2>> "$AZC_LOG"; then
        rm -rf "$WORK_DIR"
        return 0
    fi
    echo "ERROR: failed to create $TARBALL; uncompressed results are in $WORK_DIR" >&2
    return 1
}

on_interrupt() {
    trap - INT TERM
    azc_log "Interrupted; packaging what has been collected so far"
    azc_note WARN "Collection was interrupted; bundle is incomplete"
    structure_and_analyze
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

azc_detect
azc_log "VM size: ${AZC_VM_SIZE:-unknown (IMDS unreachable)}; intended hardware: GPU vendor $AZC_EXPECT_GPU_VENDOR, GPUs $AZC_EXPECT_GPU_COUNT, InfiniBand $AZC_EXPECT_IB, NVSwitch $AZC_EXPECT_NVSWITCH"
azc_log "On the PCI bus: $AZC_PCI_NVIDIA_GPUS NVIDIA GPU(s), $AZC_PCI_NVSWITCHES NVSwitch(es), $AZC_PCI_AMD_GPUS AMD GPU(s), $AZC_PCI_IB_CONTROLLERS InfiniBand controller(s)"

collect_nvidia_bug_report
collect_vm_metadata
azc_collect_image
azc_collect_os
azc_collect_hardware
azc_collect_software_state
# shellcheck disable=SC2086
azc_collect_services $AZC_SERVICES
azc_collect_logs
azc_collect_network
azc_collect_hpc_stack
if azc_want_amd; then azc_collect_amd; fi
if azc_want_nvidia; then azc_collect_nvidia; fi
run_dcgm_diag
run_health_checks
structure_and_analyze

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
