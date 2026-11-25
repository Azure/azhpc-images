#!/bin/bash
set -ex

# =============================================================================
# LEGACY / TEMPORARY FALLBACK — Non-Azure-VM (Bare-Metal) RDMA Device Naming
# =============================================================================
# Azure VM SKUs (azure_vm_regular, azure_vm_akshost) use deterministic,
# event-driven udev rules in components/add-udev-rules.sh keyed on platform-
# guaranteed Hyper-V vPCI addresses. This script is scoped out for Azure VMs
# and retained solely as a fallback for non-standard bare-metal environments
# (e.g. baremetal_1p, baremetal_3p) whose PCIe/NIC layouts vary by platform.
#
# WHY THIS APPROACH IS FRAGILE (ESPECIALLY UNDER DEVICE DROPS / RESETS):
#   1. Index shifting on dropped or missing NICs:
#      Devices are enumerated via `ibdev2netdev -v` sorted by PCI BDF and
#      assigned dense sequential indices (mlx5_ib0..N, mlx5_an0..M). If any physical HCA fails
#      to probe or drops off the PCIe bus before the first run, every subsequent
#      NIC shifts down by one index, silently breaking PCIe/NUMA/GPU-to-NIC
#      affinity (NCCL topology XMLs, rail alignment, and health checks).
#   2. Permanent index holes, drift, and out-of-order naming on late probe or
#      recovery:
#      To avoid colliding with already-renamed devices across 60s timer retries,
#      next_index() assigns (max_existing_index + 1). Consequently:
#        - A slow-probing NIC that appears after the initial pass is appended at
#          the tail (e.g. physical slot 2 becomes mlx5_ib7), breaking physical
#          ordering.
#        - A NIC that drops and later re-probes after a PCIe/firmware reset is
#          never restored to its original index (e.g. mlx5_ib2 bounces and
#          re-appears as mlx5_ib8), leaving permanent gaps and unbounded index
#          drift across repeated drop/recovery cycles.
#   3. Asynchronous race window:
#      Renaming runs post-boot via a oneshot service + 60s polling timer rather
#      than atomically inside udev ACTION=="add", so early services or workloads
#      can observe transient kernel names (mlx5_*) or race with renames.
#
# TODO (PER-ENVIRONMENT DETERMINISTIC NAMING):
#   Replace this script and its systemd service/timer for each bare-metal
#   environment (baremetal_1p, baremetal_3p, etc.) with an environment-specific,
#   deterministic udev NAME_FIXED rule (or platform topology mapping) keyed on
#   stable physical hardware identifiers (such as exact platform PCI BDF map,
#   physical PCIe/SMBIOS slot, or chassis/board topology). Each physical NIC
#   must map atomically to a fixed mlx5_ibN/mlx5_anN name on udev `add` so that
#   device drops, late probes, and resets never shift or drift sibling names.
#   Remove this script once all bare-metal environments have migrated.
# =============================================================================

if [[ "${TARGET_NODE_TYPE:-azure_vm_regular}" == azure_vm_* ]]; then
    echo "Skipping legacy persistent RDMA naming on ${TARGET_NODE_TYPE:-azure_vm_regular} (handled by udev rules)."
    exit 0
fi

# Verify that rdma_rename (with NAME_FIXED support) is already installed by
# DOCA/MOFED rdma-core, avoiding a separate rdma-core source build.
rdma_rename_bin=""
for candidate in /usr/lib/udev/rdma_rename /lib/udev/rdma_rename; do
    if [[ -x "${candidate}" ]]; then
        rdma_rename_bin="${candidate}"
        break
    fi
done
if [[ -z "${rdma_rename_bin}" ]]; then
    rdma_rename_bin="$(command -v rdma_rename || true)"
fi
if [[ -z "${rdma_rename_bin}" ]]; then
    echo "ERROR: rdma_rename not found (expected from DOCA/MOFED rdma-core)." >&2
    exit 1
fi

#
# setup systemd service (bare-metal fallback only)
#

cat <<'EOF' >/usr/sbin/azure_persistent_rdma_naming.sh
#!/bin/bash
# Legacy bare-metal RDMA naming fallback (see components/install_azure_persistent_rdma_naming.sh).
# WARNING: Sequential renaming by current PCI BDF order + `max_index + 1` is fragile
# under NIC drops, late probes, and PCIe resets (causes index shifts, holes, and drift).
# TODO: Replace with per-environment deterministic udev rules keyed on stable hardware slots/BDFs.

rdma_rename=""
for candidate in /usr/lib/udev/rdma_rename /lib/udev/rdma_rename; do
	if [[ -x "$candidate" ]]; then
		rdma_rename="$candidate"
		break
	fi
done
if [[ -z "$rdma_rename" ]]; then
	rdma_rename="$(command -v rdma_rename || true)"
fi
if [[ -z "$rdma_rename" ]]; then
	echo "ERROR: rdma_rename not found." >&2
	exit 1
fi

# Sort by normalized fixed-width lowercase hex PCI BDF (DDDDDDDD:BB:DD.F) under
# LC_ALL=C so hexadecimal domains/buses (including >16-bit domains such as VMD)
# order numerically instead of breaking under base-10 `sort -n`.
mapfile -t all_devices < <(
	ibdev2netdev -v | awk '{
		bdf = tolower($1)
		if (split(bdf, p, /[:.]/) == 4) {
			while (length(p[1]) < 8) p[1] = "0" p[1]
			while (length(p[2]) < 2) p[2] = "0" p[2]
			while (length(p[3]) < 2) p[3] = "0" p[3]
			key = p[1] ":" p[2] ":" p[3] "." p[4]
		} else {
			key = bdf
		}
		print key "\t" $2
	}' | LC_ALL=C sort -k1,1 | cut -f2
)

next_index() {
	local prefix=$1
	local max_index=-1
	local dev suffix

	for dev in "${all_devices[@]}"; do
		suffix=${dev#$prefix}
		if [[ "$dev" == "$prefix"* && "$suffix" =~ ^[0-9]+$ && "$suffix" -gt "$max_index" ]]; then
			max_index=$suffix
		fi
	done

	echo $((max_index + 1))
}

an_index=$(next_index mlx5_an)
ib_index=$(next_index mlx5_ib)

for old_device in "${all_devices[@]}"; do

	case "$old_device" in
		mlx5_ib*|mlx5_an*) continue ;;
	esac

	link_layer=$(ibv_devinfo -d "$old_device" | sed -n 's/^[\ \t]*link_layer:[\ \t]*\([a-zA-Z]*\)$/\1/p')

	if [ "$link_layer" = "InfiniBand" ]; then

		"$rdma_rename" "$old_device" NAME_FIXED "mlx5_ib${ib_index}"
		ib_index=$((ib_index + 1))

	elif [ "$link_layer" = "Ethernet" ]; then

		"$rdma_rename" "$old_device" NAME_FIXED "mlx5_an${an_index}"
		an_index=$((an_index + 1))

	else

		echo "Unknown device type for $old_device."

	fi

done
EOF
chmod 755 /usr/sbin/azure_persistent_rdma_naming.sh

cat <<'EOF' >/etc/systemd/system/azure_persistent_rdma_naming.service
[Unit]
Description=Azure persistent RDMA naming (legacy bare-metal fallback)
After=network.target systemd-udev-settle.service openibd.service
Wants=systemd-udev-settle.service

[Service]
Type=oneshot
ExecStart=/usr/sbin/azure_persistent_rdma_naming.sh
StandardOutput=journal

[Install]
WantedBy=multi-user.target
EOF

cat <<'EOF' >/etc/systemd/system/azure_persistent_rdma_naming.timer
[Unit]
Description=Retry Azure persistent RDMA naming (legacy bare-metal fallback)

[Timer]
OnBootSec=30s
OnUnitActiveSec=60s
AccuracySec=5s
Unit=azure_persistent_rdma_naming.service

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable azure_persistent_rdma_naming.service
systemctl enable azure_persistent_rdma_naming.timer
# Do NOT start the service/timer during image build: bare-metal images are built
# on Azure VM stand-ins where udev rules handle RDMA naming.
