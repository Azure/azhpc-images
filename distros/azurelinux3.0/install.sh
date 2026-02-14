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

# install utils
./install_utils.sh

# install Mellanox OFED
$COMPONENT_DIR/install_mofed.sh

# install PMIX
$COMPONENT_DIR/install_pmix.sh

# install mpi libraries
$COMPONENT_DIR/install_mpis.sh

# install mpifileutils
$COMPONENT_DIR/install_mpifileutils.sh

if [ "$GPU" = "NVIDIA" ]; then
    # install nvidia gpu driver
    $COMPONENT_DIR/install_nvidiagpudriver.sh
    
    # Install NCCL
    $COMPONENT_DIR/install_nccl.sh

    if [ "$ARCHITECTURE" = "aarch64" ]; then
        # Install nvshmem
        $COMPONENT_DIR/install_nvshmem.sh

        # Install nvloom
        $COMPONENT_DIR/install_nvloom.sh
    fi
    
    # Install NVIDIA docker container
    $COMPONENT_DIR/install_docker.sh

    # Install DCGM
    $COMPONENT_DIR/install_dcgm.sh
fi

if [ "$GPU" = "AMD" ]; then
    # Set up docker
    tdnf install -y moby-engine moby-cli
    systemctl enable docker
    systemctl restart docker

    #install rocm software stack
    $COMPONENT_DIR/install_rocm.sh    
    #install rccl and rccl-tests
    $COMPONENT_DIR/install_rccl.sh
fi

if [ "$ARCHITECTURE" != "aarch64" ]; then
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

if [ "$ARCHITECTURE" != "aarch64" ]; then
    # Install AZNFS Mount Helper
    $COMPONENT_DIR/install_aznfs.sh
fi

# install diagnostic script
$COMPONENT_DIR/install_hpcdiag.sh

# install monitor tools
$COMPONENT_DIR/install_monitoring_tools.sh

# install persistent rdma naming
$COMPONENT_DIR/install_azure_persistent_rdma_naming.sh

# add udev rule
$COMPONENT_DIR/add-udev-rules.sh

# copy test file
$COMPONENT_DIR/copy_test_file.sh

# install Azure/NHC Health Checks
$COMPONENT_DIR/install_health_checks.sh "$GPU"

# SKU Customization
$COMPONENT_DIR/setup_sku_customizations.sh

# scan vulnerabilities using Trivy
$COMPONENT_DIR/trivy_scan.sh


# add interface rules
./network-config.sh

# clear history
# Uncomment the line below if you are running this on a VM
# $UTILS_DIR/clear_history.sh
