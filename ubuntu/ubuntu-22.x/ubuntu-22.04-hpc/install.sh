#!/bin/bash
set -ex

# set properties
source ./set_properties.sh

# install utils
./install_utils.sh

# install Lustre client
$UBUNTU_COMMON_DIR/install_lustre_client.sh

# install mellanox ofed
./install_mellanoxofed.sh

# install mpi libraries
./install_mpis.sh

# install nvidia gpu driver
./install_nvidiagpudriver.sh

# Install NCCL
$UBUNTU_COMMON_DIR/install_nccl.sh

# Install NVIDIA docker container
$UBUNTU_COMMON_DIR/install_docker.sh

# cleanup downloaded tarballs - clear some space
rm -rf *.tgz *.bz2 *.tbz *.tar.gz *.run *.deb *_offline.sh
rm -rf /tmp/MLNX_OFED_LINUX* /tmp/*conf*
rm -rf /var/intel/ /var/cache/*
rm -Rf -- */

# Install DCGM
$UBUNTU_COMMON_DIR/install_dcgm.sh

# install Intel libraries
$UBUNTU_COMMON_DIR/install_intel_libs.sh

# install diagnostic script
$COMMON_DIR/install_hpcdiag.sh

# install persistent rdma naming
$COMMON_DIR/install_azure_persistent_rdma_naming.sh

# optimizations
$UBUNTU_COMMON_DIR/hpc-tuning.sh

# copy test file
$COMMON_DIR/copy_test_file.sh

# install monitor tools
$UBUNTU_COMMON_DIR/install_monitoring_tools.sh

# install AMD libs
$UBUNTU_COMMON_DIR/install_amd_libs.sh

# install Azure/NHC Health Checks
$COMMON_DIR/install_health_checks.sh

# diable auto kernel updates
$UBUNTU_COMMON_DIR/disable_auto_upgrade.sh

# Disable Predictive Network interface renaming
$UBUNTU_COMMON_DIR/disable_predictive_interface_renaming.sh

# SKU Customization
$COMMON_DIR/setup_sku_customizations.sh

# clear history
# Uncomment the line below if you are running this on a VM
# $COMMON_DIR/clear_history.sh
