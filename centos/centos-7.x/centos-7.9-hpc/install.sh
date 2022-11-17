#!/bin/bash
set -ex

# set properties
source ./set_properties.sh

# install utils
./install_utils.sh

# install compilers
./install_gcc.sh

# install mellanox ofed
./install_mellanoxofed.sh

# install mpi libraries
./install_mpis.sh

# cleanup downloaded tarballs
rm -rf *.tgz *.bz2 *.tbz *.tar.gz
rm -rf -- */

# install nvidia gpu driver
./install_nvidiagpudriver.sh

# install AMD tuned libraries
./install_amd_libs.sh

# install Intel libraries
./install_intel_libs.sh

# Install NCCL
./install_nccl.sh

# Install NVIDIA docker container
$COMMON_DIR/../centos/centos-7.x/common/install_docker.sh

# cleanup downloaded tarballs
rm -rf *.tar.gz *_offline.sh *.rpm *.run

# Install DCGM
./install_dcgm.sh

# optimizations
./hpc-tuning.sh

# Network Optimization
$COMMON_DIR/network-tuning.sh

# install persistent rdma naming
$COMMON_DIR/install_azure_persistent_rdma_naming.sh

# add udev rule
$COMMON_DIR/../centos/common/add-udev-rules.sh

# add interface rules
$COMMON_DIR/../centos/common/network-config.sh

# install diagnostic script
$COMMON_DIR/install_hpcdiag.sh

# copy test file
$COMMON_DIR/copy_test_file.sh

# disable cloud-init
./disable_cloudinit.sh

# clear history
# Uncomment the line below if you are running this on a VM
# $COMMON_DIR/clear_history.sh
