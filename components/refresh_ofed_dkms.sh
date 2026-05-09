#!/bin/bash
set -euo pipefail

# =============================================================================
# Refresh OFED DKMS modules for the running kernel
# =============================================================================
# This script is used during "in-place refresh" builds AFTER the reboot into
# the newly-installed kernel.  In prerequisites.sh we deliberately skip
# rebuilding the MOFED kernel modules (mlnx-ofed-kernel, iser, isert, srp)
# because doing so while still running on the old kernel would make the MOFED
# `pre_build` configure step probe the wrong kernel and produce an
# `mlx5_core.ko` that fails to enumerate the SR-IOV IB VFs after reboot.
#
# Now that we ARE running on the new kernel, the configure probes will be
# correct, so we can safely (re)build the OFED DKMS modules.  Without this
# step, /etc/init.d/openibd start fails because it tries to modprobe
# iser/isert/srp and the matching .ko files are missing for the running
# kernel.
#
# Idempotent: only builds modules that aren't already present for the current
# kernel.  Tolerates per-module failures so a problem in one module doesn't
# block the others.
#
# This script does NOT restart openibd; the calling pipeline is responsible
# for rebooting afterwards so the system comes up cleanly with the new OFED
# modules in place.
# =============================================================================

if ! command -v dkms &>/dev/null; then
    echo "[refresh_ofed_dkms] dkms not installed; nothing to do"
    exit 0
fi

KVER="$(uname -r)"
echo "[refresh_ofed_dkms] Running kernel: ${KVER}"

# Modules that we deferred from prerequisites.sh and now need to build for
# the running kernel.  Order matters: mlnx-ofed-kernel must be built first
# because iser/isert/srp depend on its symbols.
declare -a MODULES=(
    mlnx-ofed-kernel
    iser
    isert
    srp
)

rebuild_failed=0
for mod_name in "${MODULES[@]}"; do
    mod_source_dir=$(ls -1d /var/lib/dkms/"${mod_name}"/*/source 2>/dev/null | head -n1 || true)
    if [[ -z "${mod_source_dir}" ]]; then
        echo "[refresh_ofed_dkms] DKMS module ${mod_name} not registered; skipping"
        continue
    fi
    mod_ver=$(basename "$(dirname "${mod_source_dir}")")

    # Skip if a module is already installed for the running kernel.
    status=$(dkms status -m "${mod_name}" -v "${mod_ver}" -k "${KVER}" 2>/dev/null || true)
    if echo "${status}" | grep -qE "(installed|installed-weak)"; then
        echo "[refresh_ofed_dkms] ${mod_name}/${mod_ver} already installed for ${KVER}; skipping"
        continue
    fi

    echo "##[section][refresh_ofed_dkms] Building DKMS module ${mod_name}/${mod_ver} for kernel ${KVER}"
    if ! dkms install --no-depmod "${mod_name}/${mod_ver}" -k "${KVER}" --force; then
        echo "##[warning][refresh_ofed_dkms] dkms install failed for ${mod_name}/${mod_ver} on ${KVER}"
        rebuild_failed=1
    fi
done

# Single depmod pass so any newly-installed modules are discoverable.
depmod -a "${KVER}" || true

# NOTE: We deliberately do NOT restart openibd here.  Live-restarting openibd
# unloads mlx5_core and detaches the Azure SR-IOV IB VFs.  When the VFs come
# back via VMBus hotplug, the freshly-swapped OFED ib_ipoib does not reliably
# (re)create the ib0..ib7 IPoIB netdevs, leaving the system with LinkUp ports
# but no usable netdevs.  Instead, the build pipeline reboots after this
# script runs so the kernel comes up cleanly with the new OFED modules from
# the start (equivalent to a normal install path).

if (( rebuild_failed )); then
    echo "##[warning][refresh_ofed_dkms] One or more OFED DKMS modules failed to build"
fi

echo "[refresh_ofed_dkms] Done (reboot required to activate new modules)"
exit 0
