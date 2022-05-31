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
$UBUNTU_COMMON_DIR/install_nccl.sh

# Install NVIDIA docker container
$UBUNTU_COMMON_DIR/install_docker.sh

# cleanup downloaded tarballs
rm -rf *.tgz *.bz2 *.tbz *.tar.gz *.run *.deb *_offline.sh
rm -Rf -- */

# Install DCGM
$UBUNTU_COMMON_DIR/install_dcgm.sh 1804

# install Intel libraries
$COMMON_DIR/install_intel_libs.sh

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

# install monitor tools
$COMMON_DIR/install_monitoring_tools.sh

# diable auto kernel updates
$UBUNTU_COMMON_DIR/disable_auto_upgrade.sh

# clear history
# Uncomment the line below if you are running this on a VM
# $UBUNTU_COMMON_DIR/clear_history.sh
