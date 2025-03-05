#!/bin/bash
set -ex

# install pre-requisites
./install_prerequisites.sh

export GPU="NVIDIA"

if [[ "$#" -gt 0 ]]; then
    INPUT=$1
    if [ "$INPUT" != "NVIDIA" ]; then
        echo "Error: Invalid GPU type. Only 'NVIDIA' is implemented for this OS."
	exit 1
    fi
fi

# set properties
source ./set_properties.sh

# install utils
./install_utils.sh

# install Lustre client
$ALMA_COMMON_DIR/install_lustre_client.sh "8"

# install compilers
./install_gcc.sh

# install DOCA OFED
$ALMA_COMMON_DIR/install_doca.sh

# install PMIX
$ALMA_COMMON_DIR/install_pmix.sh

# install mpi libraries
$ALMA_COMMON_DIR/install_mpis.sh

# install nvidia gpu driver
$ALMA_COMMON_DIR/install_nvidiagpudriver.sh

# install AMD tuned libraries
$COMMON_DIR/install_amd_libs.sh

# install Intel libraries
$COMMON_DIR/install_intel_libs.sh

# cleanup downloaded tarballs - clear some space
rm -rf *.tgz *.bz2 *.tbz *.tar.gz *.run *.deb *_offline.sh
rm -rf /tmp/MLNX_OFED_LINUX* /tmp/*conf*
rm -rf /var/intel/ /var/cache/*
rm -Rf -- */

# Install NCCL
$ALMA_COMMON_DIR/install_nccl.sh

# Install NVIDIA docker container
$ALMA_COMMON_DIR/install_docker.sh

# Install DCGM
$ALMA_COMMON_DIR/install_dcgm.sh

# optimizations
$ALMA_COMMON_DIR/hpc-tuning.sh

# Install AZNFS Mount Helper
$COMMON_DIR/install_aznfs.sh

# install persistent rdma naming
$COMMON_DIR/install_azure_persistent_rdma_naming.sh

# add udev rule
$ALMA_COMMON_DIR/add-udev-rules.sh

# add interface rules
$ALMA_COMMON_DIR/network-config.sh

# install diagnostic script
$COMMON_DIR/install_hpcdiag.sh

#install monitoring tools
$COMMON_DIR/install_monitoring_tools.sh

# install Azure/NHC Health Checks
$COMMON_DIR/install_health_checks.sh

# copy test file
$COMMON_DIR/copy_test_file.sh

# disable cloud-init
$ALMA_COMMON_DIR/disable_cloudinit.sh

# SKU Customization
$COMMON_DIR/setup_sku_customizations.sh

# clear history
# Uncomment the line below if you are running this on a VM
# $COMMON_DIR/clear_history.sh

# add a security patch of CVE issue for AlmaLinux 8.7 only
./disable_user_namespaces.sh
