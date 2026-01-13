#!/bin/bash
set -ex

# Check if arguments are passed
if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Error: Missing arguments. Please provide both GPU type (NVIDIA/AMD) and SKU."
    exit 1
fi

export GPU=NVIDIA
export SKU=GB200

if [[ "$#" -gt 0 ]]; then
   if [[ "$GPU" != "NVIDIA" && "$GPU" != "AMD" ]]; then
       echo "Error: Invalid GPU type. Please specify 'NVIDIA' or 'AMD'."
       exit 1
    fi
fi

source ../../utils/set_properties.sh

./install_utils.sh

# install DOCA OFED
$COMPONENT_DIR/install_doca.sh

# install PMIX
$COMPONENT_DIR/install_pmix.sh

# install mpi libraries
$COMPONENT_DIR/install_mpis.sh

./install_nvidiagpudriver_gb200.sh

# Install NVSHMEM
./install_nvshmem_gb200.sh

# Install NVLOOM
./install_nvloom_gb200.sh

# Install NVBandwidth tool
$COMPONENT_DIR/install_nvbandwidth_tool.sh
    
# Install NCCL
$COMPONENT_DIR/install_nccl.sh

# Install NVIDIA docker container
$COMPONENT_DIR/install_docker.sh

# Install DCGM
$COMPONENT_DIR/install_dcgm.sh

# cleanup downloaded tarballs - clear some space
rm -rf *.tgz *.bz2 *.tbz *.tar.gz *.run *.deb *_offline.sh
rm -rf /tmp/MLNX_OFED_LINUX* /tmp/*conf*
rm -rf /var/intel/ /var/cache/*
rm -Rf -- */

# optimizations
$COMPONENT_DIR/hpc-tuning.sh

# install persistent rdma naming
$COMPONENT_DIR/install_azure_persistent_rdma_naming.sh

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
