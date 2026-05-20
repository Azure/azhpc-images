#!/bin/bash
set -ex

# Check if arguments are passed
if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Error: Missing arguments. Please provide both GPU type (NVIDIA/AMD) and SKU."
    exit 1
fi

export GPU=$1
export SKU=$2

if [[ "$#" -gt 0 ]]; then
   if [[ "$GPU" != "NVIDIA" && "$GPU" != "AMD" && "$GPU" != "MAIA" ]]; then
       echo "Error: Invalid GPU type. Please specify 'NVIDIA', 'AMD', or 'MAIA'."
       exit 1
    fi
fi

if [[ "$GPU" == "MAIA" ]]; then
    echo "##[section]Applying MAIA200 VM configurations"

    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y unzip zip

    # 1. GRUB: DMA memory reservation for MAIA accelerator
    echo "##[section]Configuring GRUB memmap for MAIA200"
    sudo mkdir -p /etc/default/grub.d
    # Three layers of escaping are required:
    # 1. Single quotes here → file gets: memmap=256G\\\$90G  (literal backslashes + dollar)
    # 2. bash sources the file → \\\$90G in double-quotes → \$90G  (backslash + literal $)
    # 3. GRUB shell parses grub.cfg  → \$90G → $90G  (literal $ passed to kernel)
    # Without this, GRUB expands $90G as an empty variable → kernel sees 256GG (wrong).
    echo 'GRUB_CMDLINE_LINUX="$GRUB_CMDLINE_LINUX memmap=256G\\\$90G"' | sudo tee /etc/default/grub.d/90-maia.cfg
    sudo update-grub

    # 2. Disable unattended upgrades (drivers are kernel-version-specific)
    echo "##[section]Disabling unattended upgrades for MAIA"
    sudo systemctl stop unattended-upgrades 2>/dev/null || true
    sudo systemctl disable unattended-upgrades 2>/dev/null || true
    sudo apt-mark hold linux-image-generic linux-headers-generic linux-generic 2>/dev/null || true

    # 3. Environment variables
    echo "##[section]Setting MAIA environment variables"
    cat <<'ENVEOF' | sudo tee /etc/profile.d/maiaenv.sh
# MAIA200 environment
ulimit -S -n 2048
export PATH="/opt/maia/bin:$PATH"
ENVEOF
    sudo chmod 644 /etc/profile.d/maiaenv.sh

    # 4. Crash dump configuration
    sudo sysctl -w kernel.core_pattern="/var/crash/%e_%p_%t.dmp"
    echo 'kernel.core_pattern=/var/crash/%e_%p_%t.dmp' | sudo tee -a /etc/sysctl.d/90-maia-coredump.conf
    sudo mkdir -p /var/crash

    # 5. Device node creation service (Issue 1 fix: skip dummy nodes when real driver devices exist)
    echo "##[section]Installing MAIA device node service"
    cat <<'DEVEOF' | sudo tee /usr/local/bin/create_maia_devices.sh
#!/bin/bash
# Creates placeholder /dev/apu* and /dev/maianexus* device nodes only for slots
# not already occupied by real driver-created devices (major != 1).
# This prevents dummy nodes (major 1 = /dev/null) from shadowing hardware devices,
# which causes libapu IOCTL -ENOTTY failures on every maia-smi invocation.
NUM_DEVICES="${NUM_APU_DEVICES:-8}"
for i in $(seq 0 $((NUM_DEVICES - 1))); do
    for prefix in apu maianexus; do
        DEV="/dev/${prefix}${i}"
        if [ ! -e "$DEV" ]; then
            # Only create a dummy if no real (non-null) devices exist for this prefix
            REAL_COUNT=$(ls -la /dev/${prefix}[0-9]* 2>/dev/null | awk '$5 != "1," {count++} END {print count+0}')
            if [ "$REAL_COUNT" -eq 0 ]; then
                mknod -m 0666 "$DEV" c 1 3
            fi
        fi
    done
done
DEVEOF
    sudo chmod +x /usr/local/bin/create_maia_devices.sh

    cat <<'SVCEOF' | sudo tee /etc/systemd/system/maia-devices.service
[Unit]
Description=Create MAIA APU and MaiaNexus Device Nodes
After=maia-driver-dma.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/create_maia_devices.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
SVCEOF

    # 5b. apupci driver DMA service (Issue 3 fix: load driver with dma_mem when memmap= is in cmdline)
    # The default boot loads apupci.ko via modprobe without dma_mem, so /dev/apu-dma-mem is never created
    # even though GRUB reserves 256GB DMA memory (memmap=256G$90G).
    # This service re-loads the driver using loaddriver.sh dma_mem which checks /proc/cmdline internally.
    #
    # The service also loads maianexus.ko (no systemd unit ships with the MAIA package),
    # and pre-cleans any stale /dev/apu* / /dev/maianexus* dummy stubs left behind by
    # earlier boot stages — otherwise the dummies (created with major 1,3 = /dev/null)
    # would shadow the real char devices the driver tries to register, leaving every
    # /dev/apuN as /dev/null and breaking libapu IOCTLs.
    #
    # Hardware gate: the helper script /usr/local/bin/maia-load-drivers.sh first
    # checks for a MAIA200 PCI device (1414:00bd) and exits 0 without doing
    # anything on hosts that don't have one (e.g. the Standard_D16s_v5 build
    # VM used to bake this image).  Without the gate, loaddriver.sh hangs the
    # kernel during boot on non-MAIA hosts, sshd never starts, and the build
    # pipeline's post-reboot SSH probe times out.
    echo "##[section]Installing MAIA driver loader helper"
    cat <<'LOADEROF' | sudo tee /usr/local/bin/maia-load-drivers.sh
#!/bin/bash
# Load the MAIA apupci (with DMA reserved memory) and maianexus kernel
# drivers, but only on hosts that actually have MAIA200 hardware.
# On non-MAIA hosts (e.g. the build VM), exit 0 immediately without touching
# the kernel — running loaddriver.sh there can hang/panic the kernel.

set -u

# Hardware gate: any PCI device with vendor 0x1414 (Microsoft) AND device
# 0x00bd (MAIA200) qualifies as MAIA hardware.
have_maia=0
for dev in /sys/bus/pci/devices/*; do
    [ -r "$dev/vendor" ] && [ -r "$dev/device" ] || continue
    [ "$(cat "$dev/vendor")" = "0x1414" ] || continue
    [ "$(cat "$dev/device")" = "0x00bd" ] || continue
    have_maia=1
    break
done

if [ "$have_maia" -eq 0 ]; then
    echo "maia-drivers: no MAIA200 PCI device (1414:00bd) found, skipping driver load"
    exit 0
fi

# Clear stale /dev stubs so the drivers can register their real char devices.
rm -f /dev/apu[0-9]* /dev/apu-dma-mem /dev/maianexus[0-9]* || true

# Load apupci with DMA reserved memory enabled.  loaddriver.sh uses a
# relative path for apupci.ko, so we must cd into its directory.
LOADDRIVER_DIR=/opt/maia/drivers/vfdriver/release/driver
if [ ! -x "$LOADDRIVER_DIR/loaddriver.sh" ]; then
    echo "maia-drivers: $LOADDRIVER_DIR/loaddriver.sh not found, skipping apupci"
else
    rmmod apupci 2>/dev/null || true
    if ! ( cd "$LOADDRIVER_DIR" && ./loaddriver.sh dma_mem ); then
        echo "maia-drivers: apupci load failed"
    fi
fi

# Load maianexus from the bundled per-kernel zip.
NEXUS_LOAD=/opt/maia/drivers/maianexus/utils/load_maianexus.sh
NEXUS_ZIP=/opt/maia/drivers/maianexus/maianexus_ubuntu_2404.zip
if [ ! -x "$NEXUS_LOAD" ] || [ ! -f "$NEXUS_ZIP" ]; then
    echo "maia-drivers: maianexus loader or zip not found, skipping maianexus"
else
    rmmod maianexus 2>/dev/null || true
    "$NEXUS_LOAD" -z "$NEXUS_ZIP" || echo "maia-drivers: maianexus load failed"
fi

udevadm settle --timeout=30 || true
LOADEROF
    sudo chmod +x /usr/local/bin/maia-load-drivers.sh

    echo "##[section]Installing MAIA apupci DMA driver service"
    cat <<'DMAEOF' | sudo tee /etc/systemd/system/maia-driver-dma.service
[Unit]
Description=Load MAIA apupci (with DMA reserved memory) and maianexus drivers
# Only depend on kernel auto-modload — do NOT pull in systemd-udev-settle.service,
# which can hang for hours on Azure VMs (continuous uevent stream from waagent)
# and would block multi-user.target → sshd never starts → unreachable VM.
After=systemd-modules-load.service
Before=maia-devices.service
# Skip the unit entirely if the helper script is missing (defensive — should
# never happen on an HPC image).
ConditionPathExists=/usr/local/bin/maia-load-drivers.sh

[Service]
Type=oneshot
RemainAfterExit=yes
# Cap the worst-case runtime: if anything hangs, fail the unit instead of
# blocking multi-user.target indefinitely.
TimeoutStartSec=300
ExecStart=/usr/local/bin/maia-load-drivers.sh

[Install]
WantedBy=multi-user.target
DMAEOF

    sudo systemctl daemon-reload
    sudo systemctl enable maia-driver-dma.service
    sudo systemctl enable maia-devices.service

    # NOTE: maia-guest-agent.service masking is intentionally NOT done here.
    # The MAIA guest stack (setup.sh) is installed AFTER this script and tries
    # to run `systemctl enable maia-guest-agent` during its post-install step.
    # Masking here would cause that step to fail.  Masking is applied in
    # install_dependencies.sh (hpc-image-val) immediately after setup.sh runs.

    # 6. Create MCCL log directory
    sudo mkdir -p /opt/maia/logs/mccl
    sudo chmod 777 /opt/maia/logs/mccl

    export TOP_DIR="$(dirname "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)")"
    export COMPONENT_DIR="${TOP_DIR}/components"
    export ARCHITECTURE=$(uname -m)
    export SKIP_FILES=()

    $COMPONENT_DIR/trivy_scan.sh

    echo "##[section]MAIA200 VM configurations complete"
    echo "MAIA200 SKU: guest stack is installed separately via install_dependencies.sh"
    exit 0
fi

source ../../utils/set_properties.sh
source ${UTILS_DIR}/utilities.sh

./install_utils.sh

if [ "$SKU" != "GB200" ]; then
    # update cmake
    $COMPONENT_DIR/install_cmake.sh
fi

# install DOCA OFED. Skip for non-IB SKUs. DOCA's ib_core breaks mana_ib on MANA-only hardware
if sku_has_infiniband; then
    $COMPONENT_DIR/install_doca.sh
else
    # Non-IB SKUs: install rdma-core for kernel-native IB module management (mana_ib support)
    apt-get install -y rdma-core libibverbs-dev ibverbs-utils librdmacm-dev pkg-config
    # Install libfabric — replaces UCX as the networking abstraction for MPI on non-IB SKUs
    $COMPONENT_DIR/install_libfabric.sh
    # Blacklist mana_ib — it exposes a non-functional verbs device (max_msg_size=0, no UD/SRQ,
    # guest RDMA not yet enabled) that causes UCX, libfabric verbs, and UCC to crash.
    # The mana ethernet driver (eth0/eth1) is unaffected.
    # Customers can re-enable: sudo rm /etc/modprobe.d/blacklist-mana-ib.conf && sudo modprobe mana_ib
    echo "blacklist mana_ib" | tee /etc/modprobe.d/blacklist-mana-ib.conf
fi

# install PMIX
$COMPONENT_DIR/install_pmix.sh

# install mpi libraries
$COMPONENT_DIR/install_mpis.sh

# install mpifileutils
$COMPONENT_DIR/install_mpifileutils.sh

if [ "$GPU" = "NVIDIA" ]; then
    # install nvidia gpu driver

    if [ "$SKU" = "GB200" ]; then
        # For GB200, pass SKU to install the correct driver
        ./install_nvidiagpudriver_gb200.sh

        # Install NVSHMEM
        $COMPONENT_DIR/install_nvshmem.sh

        # Install NVLOOM
        $COMPONENT_DIR/install_nvloom.sh

        # Install NVBandwidth tool
        $COMPONENT_DIR/install_nvbandwidth_tool.sh

    elif [ "$SKU" = "NCv6" ]; then
        $COMPONENT_DIR/install_nvidiagriddriver.sh
    else
        $COMPONENT_DIR/install_nvidiagpudriver.sh
    fi
    
    # Install NCCL
    $COMPONENT_DIR/install_nccl.sh
    
    # Install NVIDIA docker container
    $COMPONENT_DIR/install_docker.sh

    # Install DCGM
    $COMPONENT_DIR/install_dcgm.sh
fi

if [ "$GPU" = "AMD" ]; then
    # Set up docker
    apt-get install -y moby-engine
    systemctl enable docker
    systemctl restart docker

    #install rocm software stack
    $COMPONENT_DIR/install_rocm.sh    
    #install rccl and rccl-tests
    $COMPONENT_DIR/install_rccl.sh
fi

# install Lustre client
$COMPONENT_DIR/install_lustre_client.sh

if [ "$ARCHITECTURE" == "x86_64" ]; then

    # install AMD libs
    $COMPONENT_DIR/install_amd_libs.sh

    # install Intel libraries
    $COMPONENT_DIR/install_intel_libs.sh
fi

# install dynolog and dyno-relay-logger
$COMPONENT_DIR/install_dynolog_drl.sh

# cleanup downloaded tarballs - clear some space
rm -rf *.tgz *.bz2 *.tbz *.tar.gz *.run *.deb *_offline.sh
rm -rf /tmp/MLNX_OFED_LINUX* /tmp/*conf*
rm -rf /var/intel/
(
    shopt -s dotglob nullglob
    rm -rf -- /var/cache/* || true
    rm -Rf -- */ || true
)

# optimizations
$COMPONENT_DIR/hpc-tuning.sh

# install persistent rdma naming
$COMPONENT_DIR/install_azure_persistent_rdma_naming.sh

if [[ "$SKU" != "GB200" ]]; then

    # Install AZNFS Mount Helper
    $COMPONENT_DIR/install_aznfs.sh

    # install diagnostic script
    $COMPONENT_DIR/install_hpcdiag.sh

    # install monitor tools
    $COMPONENT_DIR/install_monitoring_tools.sh

    # Azure NHC does not yet support NCv6
    if [[ "$SKU" != "NCv6" ]]; then
        # install Azure Node Health Checks
        $COMPONENT_DIR/install_health_checks.sh "$GPU"
    fi
fi 
# write kernel and OS version metadata
$COMPONENT_DIR/write_kernel_os_version.sh
# add udev rule
$COMPONENT_DIR/add-udev-rules.sh

# copy test file
$COMPONENT_DIR/copy_test_file.sh

# disable cloud-init
$COMPONENT_DIR/disable_cloudinit.sh

# SKU Customization
$COMPONENT_DIR/setup_sku_customizations.sh

# scan vulnerabilities using Trivy
$COMPONENT_DIR/trivy_scan.sh

# diable auto kernel updates
./disable_auto_upgrade.sh

# Disable Predictive Network interface renaming
./disable_predictive_interface_renaming.sh

# clear history
# Uncomment the line below if you are running this on a VM
# $UTILS_DIR/clear_history.sh
