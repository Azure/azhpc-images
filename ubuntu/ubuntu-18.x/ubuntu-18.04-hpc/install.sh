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
rm -Rf -- */

# install nvidia gpu driver
./install_nvidiagpudriver.sh

# Install NCCL
sudo bash $COMMON_DIR/install_nccl.sh

# Install DCGM
sudo bash $COMMON_DIR/install_dcgm.sh

# install Intel libraries
./install_intel_libs.sh

# install diagnostic script
"$COMMON_DIR/install_hpcdiag.sh"

# optimizations
./hpc-tuning.sh

# copy test file
$COMMON_DIR/copy_test_file.sh

# Network Optimization
$COMMON_DIR/network-tuning.sh