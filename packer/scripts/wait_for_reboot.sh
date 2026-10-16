#!/bin/bash
# =============================================================================
# Wait for the build VM to come back from a "Reboot" provisioner and finish
# booting. Replaces fixed pause_after sleeps with readiness checks.
#
# The Reboot provisioner stores the pre-reboot boot_id in BOOT_ID_FILE. While
# we are still connected to the pre-reboot boot this script exits non-zero
# after a short sleep so the provisioner's max_retries tries again.
#
# Readiness = new boot_id + systemd finished starting units (running/degraded)
# + rocmstartup.service finished (AMD, if enabled)
# + (if WAIT_FOR_IB=true) every InfiniBand port is LinkUp and ACTIVE.
# Readiness waits are capped at READY_TIMEOUT_SECS of uptime; on timeout we
# warn and continue so later steps report the real failure, as before.
# =============================================================================
set -uo pipefail

BOOT_ID_FILE=/var/tmp/azhpc_packer_pre_reboot_boot_id
READY_TIMEOUT_SECS=${READY_TIMEOUT_SECS:-600}
WAIT_FOR_IB=${WAIT_FOR_IB:-false}
POLL_SECS=5

uptime_secs() {
    local up
    read -r up _ < /proc/uptime
    echo "${up%.*}"
}

current_boot_id=$(cat /proc/sys/kernel/random/boot_id)
previous_boot_id=$(cat "${BOOT_ID_FILE}" 2>/dev/null || true)

if [[ -z "${previous_boot_id}" ]]; then
    echo "ERROR: ${BOOT_ID_FILE} not found; the preceding Reboot provisioner must record the boot_id" >&2
    exit 1
fi

if [[ "${current_boot_id}" == "${previous_boot_id}" ]]; then
    echo "VM has not rebooted yet (boot_id ${current_boot_id}); retrying..."
    sleep 20
    exit 1
fi

echo "VM rebooted (boot_id ${previous_boot_id} -> ${current_boot_id}), uptime $(uptime_secs)s"

while :; do
    state=$(systemctl is-system-running 2>/dev/null)
    case "${state}" in
        running|degraded) break ;;
    esac
    if (( $(uptime_secs) >= READY_TIMEOUT_SECS )); then
        echo "##[warning]systemd still '${state}' after ${READY_TIMEOUT_SECS}s of uptime; continuing"
        break
    fi
    sleep "${POLL_SECS}"
done
echo "systemd state: ${state} (uptime $(uptime_secs)s)"
if [[ "${state}" == "degraded" ]]; then
    systemctl --failed --no-pager || true
fi

# rocmstartup.service (AMD, see components/install_rocm.sh) is Type=simple, so
# systemd reports startup complete while it is still waiting to modprobe amdgpu.
if systemctl is-enabled --quiet rocmstartup.service 2>/dev/null; then
    while systemctl is-active --quiet rocmstartup.service; do
        if (( $(uptime_secs) >= READY_TIMEOUT_SECS )); then
            echo "##[warning]rocmstartup.service still running after ${READY_TIMEOUT_SECS}s of uptime; continuing"
            break
        fi
        sleep "${POLL_SECS}"
    done
    echo "rocmstartup.service: $(systemctl is-active rocmstartup.service) (uptime $(uptime_secs)s)"
fi

ib_ports_not_ready() {
    local port link_layer phys_state port_state
    for port in /sys/class/infiniband/*/ports/*; do
        [[ -d "${port}" ]] || continue
        link_layer=$(cat "${port}/link_layer" 2>/dev/null)
        [[ "${link_layer}" == "InfiniBand" ]] || continue
        phys_state=$(cat "${port}/phys_state" 2>/dev/null)
        port_state=$(cat "${port}/state" 2>/dev/null)
        if [[ "${phys_state}" != *LinkUp* || "${port_state}" != *ACTIVE* ]]; then
            echo "${port#/sys/class/infiniband/} (${phys_state:-?}, ${port_state:-?})"
        fi
    done
}

if [[ "${WAIT_FOR_IB}" == "true" ]]; then
    while :; do
        pending=$(ib_ports_not_ready)
        [[ -z "${pending}" ]] && break
        if (( $(uptime_secs) >= READY_TIMEOUT_SECS )); then
            echo "##[warning]InfiniBand ports not ready after ${READY_TIMEOUT_SECS}s of uptime; continuing:"
            echo "${pending}"
            break
        fi
        sleep "${POLL_SECS}"
    done
    [[ -z "${pending}" ]] && echo "No InfiniBand ports pending LinkUp/ACTIVE (uptime $(uptime_secs)s)"
fi

rm -f "${BOOT_ID_FILE}"
echo "VM ready after reboot (uptime $(uptime_secs)s)"
