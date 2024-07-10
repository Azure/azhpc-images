#!/bin/bash
set -ex

# install pre-requisites
./install_prerequisites.sh

# set properties
source ./set_properties.sh

# remove packages requiring Ubuntu Pro for security updates
$UBUNTU_COMMON_DIR/remove_unused_packages.sh

# install utils
./install_utils.sh

# install Lustre client
$UBUNTU_COMMON_DIR/install_lustre_client.sh

# install mellanox ofed
./install_mellanoxofed.sh

# install PMIX
$UBUNTU_COMMON_DIR/install_pmix.sh

# install mpi libraries
./install_mpis.sh

# Set up docker
apt-get install -y moby-engine
systemctl enable docker
systemctl restart docker

# cleanup downloaded tarballs - clear some space
rm -rf *.tgz *.bz2 *.tbz *.tar.gz *.run *.deb *_offline.sh
rm -rf /tmp/MLNX_OFED_LINUX* /tmp/*conf*
rm -rf /var/intel/ /var/cache/*
rm -Rf -- */

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

#install rocm software stack
./install_rocm.sh

#install rccl and rccl-tests
./install_rccl.sh

# clear history
# Uncomment the line below if you are running this on a VM
# $COMMON_DIR/clear_history.sh
