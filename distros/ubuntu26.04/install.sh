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
   if [[ "$GPU" != "NVIDIA" && "$GPU" != "AMD" ]]; then
       echo "Error: Invalid GPU type. Please specify 'NVIDIA' or 'AMD'."
       exit 1
    fi
fi

# GB200 builds on Ubuntu 26.04 are intentionally disabled for now: the GB200
# install path depends on install_nvidiagpudriver_gb200.sh, NVSHMEM, NVLOOM,
# nvbandwidth and the linux-azure-nvidia kernel meta, none of which have been
# validated against the resolute / 7.0 kernel yet. Re-enable once those
# components are ready.
if [[ "$SKU" == "GB200" ]]; then
    echo "##[error]GB200 SKU is not supported on Ubuntu 26.04 yet (disabled pending validation)."
    exit 1
fi

source ../../utils/set_properties.sh

./install_utils.sh

if [ "$SKU" != "GB200" ]; then
    # update cmake
    $COMPONENT_DIR/install_cmake.sh

fi

# install Lustre client
# Skipped on Ubuntu 26.04: the AMLFS PMC repo doesn't publish amlfs-lustre-client
# packages for resolute / kernel 7.0 yet, so the install would fail.
# $COMPONENT_DIR/install_lustre_client.sh
echo "##[warning]Skipping Lustre client install on Ubuntu 26.04 (no AMLFS packages for this kernel/distro yet)."

# install DOCA OFED
# On Ubuntu 26.04 install_doca.sh skips the DOCA-OFED kernel-module install
# (no NVIDIA-published DOCA-Host package yet, and the Ubuntu universe
# `doca-ofed-26.01-dkms` path was deferred too). It still installs upstream
# rdma-core userspace tools so HPC-X (inbox build) and IB diagnostics work.
$COMPONENT_DIR/install_doca.sh

# install PMIX
# On Ubuntu 26.04 install_pmix.sh installs pmix/libevent/libhwloc directly from
# the Ubuntu universe repo (no Microsoft PMC dependency), so this should succeed
# under normal circumstances.
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

# install dynolog and dyno-relay-logger
$COMPONENT_DIR/install_dynolog_drl.sh

# cleanup downloaded tarballs - clear some space
rm -rf *.tgz *.bz2 *.tbz *.tar.gz *.run *.deb *_offline.sh
rm -rf /tmp/MLNX_OFED_LINUX* /tmp/*conf*
rm -rf /var/intel/ /var/cache/*
rm -Rf -- */

# optimizations
$COMPONENT_DIR/hpc-tuning.sh

# install persistent rdma naming
# This service relies on ibdev2netdev / ibv_devinfo from DOCA-OFED user-space tools.
# Run as best-effort on Ubuntu 26.04 since DOCA-OFED is skipped.
$COMPONENT_DIR/install_azure_persistent_rdma_naming.sh || echo "##[warning]install_azure_persistent_rdma_naming.sh failed on Ubuntu 26.04 (DOCA-OFED skipped); continuing."

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
