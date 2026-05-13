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

source ../../utils/set_properties.sh

./install_utils.sh

if [ "$SKU" != "GB200" ]; then
    # update cmake
    $COMPONENT_DIR/install_cmake.sh

fi

# install Lustre client
$COMPONENT_DIR/install_lustre_client.sh

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
