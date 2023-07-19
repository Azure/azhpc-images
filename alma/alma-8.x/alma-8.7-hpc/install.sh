#!/bin/bash
set -ex

# set properties
source ./set_properties.sh

# install spack
$ALMA_COMMON_DIR/install_spack.sh
# Activate the environment/ container
source /etc/profile
export PATH="/sbin:/bin:/usr/sbin:/usr/bin:$PATH"

# install compilers
./install_gcc.sh

# install AMD tuned libraries
$ALMA_COMMON_DIR/install_amd_libs.sh

# install utils
./install_utils.sh

# install Lustre client
$ALMA_COMMON_DIR/install_lustre_client.sh "8"

# install mellanox ofed
./install_mellanoxofed.sh

# install mpi libraries
./install_mpis.sh

# install nvidia gpu driver
./install_nvidiagpudriver.sh

# cleanup downloaded tarballs - clear some space
rm -rf *.tgz *.bz2 *.tbz *.tar.gz *.run *.deb
rm -rf /tmp/MLNX_OFED_LINUX* /tmp/*conf*
rm -rf /var/cache/*
rm -Rf -- */

# install Intel libraries
$COMMON_DIR/install_intel_libs.sh

# Install NCCL
$ALMA_COMMON_DIR/install_nccl.sh

spack clean -a
spack gc -y

# Install NVIDIA docker container
$COMMON_DIR/../alma/alma-8.x/common/install_docker.sh

# Install DCGM
./install_dcgm.sh

# optimizations
./hpc-tuning.sh

# install persistent rdma naming
$COMMON_DIR/install_azure_persistent_rdma_naming.sh

# add udev rule
$ALMA_COMMON_DIR/add-udev-rules.sh

# add interface rules
$ALMA_COMMON_DIR/network-config.sh

# install diagnostic script
$COMMON_DIR/install_hpcdiag.sh

#install monitoring tools
$ALMA_COMMON_DIR/install_monitoring_tools.sh

# install Azure/NHC Health Checks
$COMMON_DIR/install_health_checks.sh

# copy test file
$COMMON_DIR/copy_test_file.sh

# disable cloud-init
$ALMA_COMMON_DIR/disable_cloudinit.sh

# SKU Customization
$COMMON_DIR/setup_sku_customizations.sh

# clear history
# Uncomment the line below if you are running this on a VM
# $COMMON_DIR/clear_history.sh
