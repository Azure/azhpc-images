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
    echo "##[section]Installing MAIA apupci DMA driver service"
    cat <<'DMAEOF' | sudo tee /etc/systemd/system/maia-driver-dma.service
[Unit]
Description=Load MAIA apupci (with DMA reserved memory) and maianexus drivers
# Run after auto-load + udev so we can clear stale stubs and reload cleanly
After=systemd-modules-load.service systemd-udev-settle.service
Wants=systemd-udev-settle.service
Before=maia-devices.service

[Service]
Type=oneshot
RemainAfterExit=yes
# Clear any stale stubs from earlier boot stages so the kernel drivers can
# register their real char devices unimpeded.
ExecStartPre=/bin/sh -c 'rm -f /dev/apu[0-9]* /dev/apu-dma-mem /dev/maianexus[0-9]* || true'
ExecStart=/bin/bash -c '\
    LOADDRIVER_DIR=/opt/maia/drivers/vfdriver/release/driver; \
    if [ ! -x "$LOADDRIVER_DIR/loaddriver.sh" ]; then \
        echo "maia-driver-dma: $LOADDRIVER_DIR/loaddriver.sh not found, skipping apupci"; \
    else \
        rmmod apupci 2>/dev/null || true; \
        (cd "$LOADDRIVER_DIR" && ./loaddriver.sh dma_mem) || echo "maia-driver-dma: apupci load failed"; \
    fi; \
    NEXUS_LOAD=/opt/maia/drivers/maianexus/utils/load_maianexus.sh; \
    NEXUS_ZIP=/opt/maia/drivers/maianexus/maianexus_ubuntu_2404.zip; \
    if [ ! -x "$NEXUS_LOAD" ] || [ ! -f "$NEXUS_ZIP" ]; then \
        echo "maia-driver-dma: maianexus loader or zip not found, skipping maianexus"; \
    else \
        rmmod maianexus 2>/dev/null || true; \
        "$NEXUS_LOAD" -z "$NEXUS_ZIP" || echo "maia-driver-dma: maianexus load failed"; \
    fi; \
    udevadm settle --timeout=30 || true'

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
