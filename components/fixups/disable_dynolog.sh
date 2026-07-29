#!/bin/bash
# =============================================================================
# One-off in-place-refresh fix-up: disable dynolog services
# =============================================================================
# dynolog holds an exclusive GPU profiling context (DCGM_FI_PROF_* fields),
# which clashes with dcgm-exporter / other profiling clients (only one
# profiling client per GPU at a time). This fix-up stops and disables the
# dynolog services so the GPU profiling context is released, then verifies
# they are inactive.
#
# Intended to be run via the Packer `extra_provision_script` hook on a
# throwaway branch, e.g.:
#   REFRESH_MODE=true SKIP_PREREQUISITES=true \
#   EXTRA_PROVISION_SCRIPT=components/fixups/disable_dynolog.sh \
#   CREATE_IMAGE=true
#
# Runs as root (invoked with sudo -E by the provisioner).
# =============================================================================
set -euo pipefail

SERVICES=(dynolog.service dyno-relay-logger.service)

echo "Disabling dynolog services: ${SERVICES[*]}"

for svc in "${SERVICES[@]}"; do
    if systemctl list-unit-files "$svc" --no-legend | grep -q "$svc"; then
        echo "Stopping and disabling $svc"
        systemctl stop "$svc" 2>/dev/null || true
        systemctl disable "$svc" 2>/dev/null || true
    else
        echo "Service $svc not present; skipping"
    fi
done

systemctl daemon-reload

echo "Verifying dynolog services are inactive:"
rc=0
for svc in "${SERVICES[@]}"; do
    if systemctl list-unit-files "$svc" --no-legend | grep -q "$svc"; then
        state=$(systemctl is-active "$svc" 2>/dev/null || true)
        enabled=$(systemctl is-enabled "$svc" 2>/dev/null || true)
        echo "  $svc: active=$state enabled=$enabled"
        if [[ "$state" == "active" ]]; then
            echo "  ERROR: $svc is still active"
            rc=1
        fi
    fi
done

exit $rc
