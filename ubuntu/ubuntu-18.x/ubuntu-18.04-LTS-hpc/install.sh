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

# install nvidia gpu driver
./install_nvidiagpudriver.sh

# Install NCCL
./install_nccl.sh

# cleanup downloaded tarballs
rm -rf *.tgz *.bz2 *.tbz *.tar.gz *.run *.deb *_offline.sh
rm -Rf -- */

# Install DCGM
$UBUNTU_COMMON_DIR/install_dcgm.sh

# install Intel libraries
$UBUNTU_COMMON_DIR/install_intel_libs.sh

# install diagnostic script
$COMMON_DIR/install_hpcdiag.sh

# optimizations
$UBUNTU_COMMON_DIR/hpc-tuning.sh

# SKU Customization
$COMMON_DIR/setup_sku_customizations.sh

# copy test file
$COMMON_DIR/copy_test_file.sh

# diable auto kernel updates
$UBUNTU_COMMON_DIR/disable_auto_upgrade.sh

# clear history
# Uncomment the line below if you are running this on a VM
# $COMMON_DIR/clear_history.sh
