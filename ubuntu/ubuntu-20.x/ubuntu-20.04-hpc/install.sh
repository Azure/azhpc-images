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

# cleanup downloaded tarballs
rm -rf *.tgz *.bz2 *.tbz *.tar.gz
rm -Rf -- */

# install nvidia gpu driver
./install_nvidiagpudriver.sh

# Install NCCL
$UBUNTU_COMMON_DIR/install_nccl.sh

# Install DCGM
./install_dcgm.sh

# install Intel libraries
./install_intel_libs.sh

# install diagnostic script
$COMMON_DIR/install_hpcdiag.sh

# install persistent rdma naming
$COMMON_DIR/install_azure_persistent_rdma_naming.sh

# optimizations
$UBUNTU_COMMON_DIR/hpc-tuning.sh

# Network Optimization
$COMMON_DIR/network-tuning.sh

# copy test file
$COMMON_DIR/copy_test_file.sh

# diable auto kernel updates
./disable_auto_upgrade.sh
