#!/bin/bash
set -ex

# set configuration
source ./config

# set properties
source ./set_properties.sh

# SLE version specific fixes
./fixes.sh

# install utils
../common/install_utils.sh

# install compilers
../common/install_gcc.sh

# install mellanox ofed
../common/install_mellanoxofed.sh

# install mpi libraries
../common/install_mpis.sh

# install nvidia gpu driver
../common/install_nvidiagpudriver.sh

# Install NCCL
../common/install_nccl.sh

# install AMD tuned libraries
../common/install_amd_libs.sh

# install Intel libraries
../common/install_intel_libs.sh

# Install NVIDIA docker container
../common/install_docker.sh

# Install Nvidia Datacenter GPU Manager (DCGM)
../common/install_dcgm.sh

# optimizations
../common/hpc-tuning.sh

# Network Optimization
$COMMON_DIR/network-tuning.sh

# copy test file
$COMMON_DIR/copy_test_file.sh

# install diagnostic script
$COMMON_DIR/install_hpcdiag.sh

# install persistent rdma naming
#
# SUSE ships the rdma core userspace and libraries package by default
# and provides persistent naming through udev rules
# see for example /usr/lib/udev/rules.d/60-rdma-persistent-naming.rules

# cleanup downloaded tarballs
rm -rf *.tgz *.bz2 *.tbz *.tar.gz *.run *.deb *_offline.sh
# cleanup directories
rm -rf -- */

# if you want to use it as golden-image pls. run
#
#/usr/sbin/clone-master-clean-up
#/usr/sbin/waagent -force -deprovision+user && export HISTSIZE=0 && sync

