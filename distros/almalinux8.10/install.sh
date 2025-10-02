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
    if [ "$GPU" == "AMD" ]; then
        GPUi="AMD"
        echo "Error: AMD GPU support is not implemented yet for AlmaLinux."
        exit 1
    elif [ "$GPU" != "NVIDIA" ]; then
        echo "Error: Invalid GPU type. Please specify 'NVIDIA' or 'AMD'."
	    exit 1
    fi
fi

source ../../utils/set_properties.sh

./install_utils.sh

# update cmake
$COMPONENT_DIR/install_cmake.sh

# install Lustre client
$COMPONENT_DIR/install_lustre_client.sh

# install DOCA OFED
$COMPONENT_DIR/install_doca.sh

# install PMIX
$COMPONENT_DIR/install_pmix.sh

# install mpi libraries
$COMPONENT_DIR/install_mpis.sh

# install nvidia gpu driver
$COMPONENT_DIR/install_nvidiagpudriver.sh "$SKU"

# Install NCCL
$COMPONENT_DIR/install_nccl.sh

# Install NVIDIA docker container
$COMPONENT_DIR/install_docker.sh

# Install DCGM
$COMPONENT_DIR/install_dcgm.sh

# install AMD tuned libraries
$COMPONENT_DIR/install_amd_libs.sh

# install Intel libraries
$COMPONENT_DIR/install_intel_libs.sh

# cleanup downloaded tarballs - clear some space
rm -rf *.tgz *.bz2 *.tbz *.tar.gz *.run *.deb *_offline.sh
rm -rf /tmp/MLNX_OFED_LINUX* /tmp/*conf*
rm -rf /var/intel/ /var/cache/*
rm -Rf -- */

# optimizations
$COMPONENT_DIR/hpc-tuning.sh

# install diagnostic script
$COMPONENT_DIR/install_hpcdiag.sh

# Install AZNFS Mount Helper
$COMPONENT_DIR/install_aznfs.sh

# install monitor tools
$COMPONENT_DIR/install_monitoring_tools.sh

# install persistent rdma naming
$COMPONENT_DIR/install_azure_persistent_rdma_naming.sh

# copy test file
$COMPONENT_DIR/copy_test_file.sh

# install Azure/NHC Health Checks
$COMPONENT_DIR/install_health_checks.sh "$GPU"

# disable cloud-init
$COMPONENT_DIR/disable_cloudinit.sh

# SKU Customization
$COMPONENT_DIR/setup_sku_customizations.sh

# scan vulnerabilities using Trivy
$COMPONENT_DIR/trivy_scan.sh

# add interface rules
./network-config.sh

# clear history
# Uncomment the line below if you are running this on a VM
# $UTILS_DIR/clear_history.sh