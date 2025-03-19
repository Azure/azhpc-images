#!/bin/bash
set -ex


# extend homedir to something usefull
lvextend -L 10GB /dev/rootvg/homelv || echo "continuing...."
lvextend -L 11GB /dev/rootvg/tmplv || echo "continuing...."
lvextend -L 14GB /dev/rootvg/rootlv || echo "continuing...."
lvextend -L 12GB /dev/rootvg/varlv || echo "continuing...."
lvextend -l +100%FREE /dev/rootvg/usrlv || echo "continuing...."
xfs_growfs /dev/rootvg/homelv
xfs_growfs /dev/rootvg/tmplv
xfs_growfs /dev/rootvg/rootlv
xfs_growfs /dev/rootvg/varlv
xfs_growfs /dev/rootvg/usrlv

df -h

# install pre-requisites
./install_prerequisites.sh

export GPU="NVIDIA"

if [[ "$#" -gt 0 ]]; then
    INPUT=$1
    if [ "$INPUT" != "NVIDIA" ]; then
        echo "Error: Invalid GPU type. Only 'NVIDIA' is implemented for this OS."
	exit 1
    fi
fi

# set properties
source ./set_properties.sh

# install utils
./install_utils.sh

# install Lustre client
$RHEL_COMMON_DIR/install_lustre_client.sh "8"

# install compilers
./install_gcc.sh

# install DOCA OFED
$RHEL_COMMON_DIR/install_doca.sh

# install PMIX
$RHEL_COMMON_DIR/install_pmix.sh

# install mpi libraries
$RHEL_COMMON_DIR/install_mpis.sh

# install nvidia gpu driver
$RHEL_COMMON_DIR/install_nvidiagpudriver.sh

# install AMD tuned libraries
$COMMON_DIR/install_amd_libs.sh

# install Intel libraries
$COMMON_DIR/install_intel_libs.sh

# cleanup downloaded tarballs - clear some space
rm -rf *.tgz *.bz2 *.tbz *.tar.gz *.run *.deb *_offline.sh
rm -rf /tmp/MLNX_OFED_LINUX* /tmp/*conf*
rm -rf /var/intel/ /var/cache/*
rm -Rf -- */

# Install NCCL
$RHEL_COMMON_DIR/install_nccl.sh

# Install NVIDIA docker container
$RHEL_COMMON_DIR/install_docker.sh

# Install DCGM
$RHEL_COMMON_DIR/install_dcgm.sh

# optimizations
$RHEL_COMMON_DIR/hpc-tuning.sh

# Install AZNFS Mount Helper
$COMMON_DIR/install_aznfs.sh

# install persistent rdma naming
$COMMON_DIR/install_azure_persistent_rdma_naming.sh

# add udev rule
$RHEL_COMMON_DIR/add-udev-rules.sh

# add interface rules
$RHEL_COMMON_DIR/network-config.sh

# install diagnostic script
$COMMON_DIR/install_hpcdiag.sh

#install monitoring tools
$COMMON_DIR/install_monitoring_tools.sh

df -h

# install Azure/NHC Health Checks
$COMMON_DIR/install_health_checks.sh NVIDIA

# copy test file
$COMMON_DIR/copy_test_file.sh

# disable cloud-init
$RHEL_COMMON_DIR/disable_cloudinit.sh

# SKU Customization
$COMMON_DIR/setup_sku_customizations.sh

# clear history
# Uncomment the line below if you are running this on a VM
$COMMON_DIR/clear_history.sh

# add a security patch of CVE issue for AlmaLinux 8.7 only
# ./disable_user_namespaces.sh
