#!/bin/bash
set -ex

# set properties
source ./set_properties.sh

# install utils
./install_utils.sh

# install mellanox ofed
./install_mellanoxofed.sh

# install mpi libraries
./install_mpis.sh

# Install moby-engine
apt-get install -y moby-engine
systemctl enable docker
systemctl restart docker

# cleanup downloaded tarballs
rm -rf *.tgz *.bz2 *.tbz *.tar.gz *.run *.deb *_offline.sh
rm -Rf -- */

# install Intel libraries
$UBUNTU_COMMON_DIR/install_intel_libs.sh

# install diagnostic script
$COMMON_DIR/install_hpcdiag.sh

# install persistent rdma naming
$COMMON_DIR/install_azure_persistent_rdma_naming.sh

# optimizations
$UBUNTU_COMMON_DIR/hpc-tuning.sh

# SKU Customization
$COMMON_DIR/setup_sku_customizations.sh

# copy test file
$COMMON_DIR/copy_test_file.sh

# diable auto kernel updates
$UBUNTU_COMMON_DIR/disable_auto_upgrade.sh

#install rocm software stack
./install_rocm.sh

#install rccl and rccl-tests
./install_rccl.sh

# clear history
# Uncomment the line below if you are running this on a VM
# $UBUNTU_COMMON_DIR/clear_history.sh

