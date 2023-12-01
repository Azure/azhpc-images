#!/bin/bash
set -ex

# set properties
source ./set_properties.sh

# extend homedir to something usefull
lvextend -L 10GB /dev/rootvg/homelv || echo "continuing...."
lvextend -L 4GB /dev/rootvg/tmplv || echo "continuing...."
lvextend -L 14GB /dev/rootvg/rootlv || echo "continuing...."
lvextend -L 12GB /dev/rootvg/usrlv || echo "continuing...."
xfs_growfs /dev/rootvg/homelv
xfs_growfs /dev/rootvg/tmplv
xfs_growfs /dev/rootvg/rootlv
xfs_growfs /dev/rootvg/usrlv

exit

# install utils
./install_utils.sh

# install compilers
./install_gcc.sh

# install mellanox ofed
./install_mellanoxofed.sh

# install mpi libraries
./install_mpis.sh

# install nvidia gpu driver
./install_nvidiagpudriver.sh

# install AMD tuned libraries
./install_amd_libs.sh

# install Intel libraries
./install_intel_libs.sh

# Install NCCL
./install_nccl.sh

# Install NVIDIA docker container
./install_docker.sh

# Install DCGM
./install_dcgm.sh

# optimizations
./hpc-tuning.sh

# install persistent rdma naming
$COMMON_DIR/install_azure_persistent_rdma_naming.sh

# add udev rule
$COMMON_DIR/../rhel/common/add-udev-rules.sh

# add interface rules
$COMMON_DIR/../rhel/common/network-config.sh

# install diagnostic script
$COMMON_DIR/install_hpcdiag.sh

# install monitoring tools
$COMMON_DIR/../rhel/common/install_monitoring_tools.sh

# install AMD libs
$COMMON_DIR/../rhel/common/install_amd_libs.sh

# install Azure/NHC Health Checks
$COMMON_DIR/install_health_checks.sh

# copy test file
$COMMON_DIR/copy_test_file.sh

# disable cloud-init
$COMMON_DIR/disable_cloudinit.sh

# SKU Customization
$COMMON_DIR/setup_sku_customizations.sh

# clear history
# Uncomment the line below if you are running this on a VM
# $COMMON_DIR/clear_history.sh
