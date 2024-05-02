#!/bin/bash
set -ex

# install pre-requisites
./install_prerequisites.sh

# set properties
source ./set_properties.sh

# install utils
./install_utils.sh

# install Lustre client
# $MARINER_COMMON_DIR/install_lustre_client.sh "8"

# install mellanox ofed
./install_mellanoxofed.sh

# install mpi libraries
./install_mpis.sh

# install nvidia gpu driver
./install_nvidiagpudriver.sh

# install AMD tuned libraries
./install_amd_libs.sh

# install Intel libraries
$MARINER_COMMON_DIR/install_intel_libs.sh

# cleanup downloaded tarballs - clear some space
rm -rf *.tgz *.bz2 *.tbz *.tar.gz *.run *.deb
rm -rf /tmp/MLNX_OFED_LINUX* /tmp/*conf*
rm -rf /var/cache/*
rm -Rf -- */

# Install NCCL
$MARINER_COMMON_DIR/install_nccl.sh

# Install NVIDIA docker container
./install_docker.sh

# Install DCGM
./install_dcgm.sh

# optimizations
./hpc-tuning.sh

# install persistent rdma naming
$COMMON_DIR/install_azure_persistent_rdma_naming.sh

# add udev rule
$MARINER_COMMON_DIR/add-udev-rules.sh

# add interface rules
# $MARINER_COMMON_DIR/network-config.sh

# install diagnostic script
$COMMON_DIR/install_hpcdiag.sh

#install monitoring tools
$MARINER_COMMON_DIR/install_monitoring_tools.sh

# install Azure/NHC Health Checks
$COMMON_DIR/install_health_checks.sh

# copy test file
$COMMON_DIR/copy_test_file.sh

# disable cloud-init
$MARINER_COMMON_DIR/disable_cloudinit.sh

# SKU Customization
$COMMON_DIR/setup_sku_customizations.sh

# clear history
# Uncomment the line below if you are running this on a VM
# $COMMON_DIR/clear_history.sh
