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

# install nvidia gpu driver
#./install_nvidiagpudriver.sh

# install AMD tuned libraries
./install_amd_libs.sh

# install Intel libraries
./install_intel_libs.sh

# add udev rule
$COMMON_DIR/../centos/common/add-udev-rules.sh

# add interface rules
$COMMON_DIR/../centos/common/network-config.sh

# optimizations
./hpc-tuning.sh

# copy test file
$COMMON_DIR/copy_test_file.sh

# install diagnostic script
"$COMMON_DIR/install_hpcdiag.sh"

# install persistent rdma naming
$COMMON_DIR/install_azure_persistent_rdma_naming.sh
