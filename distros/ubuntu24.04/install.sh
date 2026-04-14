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

    # 1. GRUB: DMA memory reservation for MAIA accelerator
    echo "##[section]Configuring GRUB memmap for MAIA200"
    sudo mkdir -p /etc/default/grub.d
    echo 'GRUB_CMDLINE_LINUX="$GRUB_CMDLINE_LINUX memmap=256G\$90G"' | sudo tee /etc/default/grub.d/90-maia.cfg
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

    # 5. Device node creation service
    echo "##[section]Installing MAIA device node service"
    cat <<'DEVEOF' | sudo tee /usr/local/bin/create_maia_devices.sh
#!/bin/bash
NUM_DEVICES=${NUM_APU_DEVICES:-8}
for i in $(seq 0 $((NUM_DEVICES - 1))); do
    [ -e /dev/apu${i} ] || mknod -m 0666 /dev/apu${i} c 1 3
    [ -e /dev/maianexus${i} ] || mknod -m 0666 /dev/maianexus${i} c 1 3
done
DEVEOF
    sudo chmod +x /usr/local/bin/create_maia_devices.sh

    cat <<'SVCEOF' | sudo tee /etc/systemd/system/maia-devices.service
[Unit]
Description=Create MAIA APU and MaiaNexus Device Nodes
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/create_maia_devices.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
SVCEOF
    sudo systemctl daemon-reload
    sudo systemctl enable maia-devices.service

    # 6. Create MCCL log directory
    sudo mkdir -p /opt/maia/logs/mccl
    sudo chmod 777 /opt/maia/logs/mccl

    echo "##[section]MAIA200 VM configurations complete"
    echo "MAIA200 SKU: guest stack is installed separately via install_dependencies.sh"
    exit 0
fi

source ../../utils/set_properties.sh

./install_utils.sh

if [ "$SKU" != "GB200" ]; then
    # update cmake
    $COMPONENT_DIR/install_cmake.sh

fi

# install Lustre client
$COMPONENT_DIR/install_lustre_client.sh

# install DOCA OFED
$COMPONENT_DIR/install_doca.sh

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

if [ "$ARCHITECTURE" == "x86_64" ]; then

    # install AMD libs
    $COMPONENT_DIR/install_amd_libs.sh

    # install Intel libraries
    $COMPONENT_DIR/install_intel_libs.sh
fi

# cleanup downloaded tarballs - clear some space
rm -rf *.tgz *.bz2 *.tbz *.tar.gz *.run *.deb *_offline.sh
rm -rf /tmp/MLNX_OFED_LINUX* /tmp/*conf*
rm -rf /var/intel/ /var/cache/*
rm -Rf -- */

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

    # install Azure/NHC Health Checks
    $COMPONENT_DIR/install_health_checks.sh "$GPU"
fi 

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
