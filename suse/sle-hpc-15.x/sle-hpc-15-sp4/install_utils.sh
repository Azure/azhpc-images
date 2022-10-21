#!/bin/bash
set -ex

# Install pre-reqs and development tools
#

# Add additional repositories

#-------------------------------------------------------------------
# Intel provides oneapi RPM packages for SUSE, so we only need to add the repositories and install the packages
#-------------------------------------------------------------------
# see
# https://www.intel.com/content/www/us/en/develop/documentation/installation-guide-for-intel-oneapi-toolkits-linux/top/installation/install-using-package-managers/yum-dnf-zypper.html

# import package signing keys
rpm --import https://yum.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB
# add repository
zypper -n addrepo -f -g https://yum.repos.intel.com/oneapi oneAPI
# fetch key
zypper --non-interactive --gpg-auto-import-keys refresh

# list all packages
# sudo -E zypper pa -ir oneAPI
#-------------------------------------------------------------------

#-------------------------------------------------------------------
# Nvidia provide certified packages for SLES 15, so we only need to add the repositories and install the packages
#-------------------------------------------------------------------
# import cuda signing key
rpm --import https://developer.download.nvidia.com/compute/cuda/repos/sles15/x86_64/D42D0685.pub

# CUDA driver (nvidia provides a repo file)
zypper addrepo -f -g https://developer.download.nvidia.com/compute/cuda/repos/sles15/x86_64/cuda-sles15.repo
# fetch key
zypper --non-interactive --gpg-auto-import-keys refresh

#-------------------------------------------------------------------
# Container Repository
#-------------------------------------------------------------------
# Docker is shipped with SLES by default
# with SLES HPC we need to enable the Container repository
SUSEConnect -p sle-module-containers/15.4/x86_64

#-------------------------------------------------------------------
# nvidia container repo
#-------------------------------------------------------------------
# see https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html
# Check https://nvidia.github.io/libnvidia-container
zypper addrepo -f -g https://nvidia.github.io/libnvidia-container/sles15.3/libnvidia-container.repo
# fetch key
zypper --non-interactive --gpg-auto-import-keys refresh

#-------------------------------------------------------------------
# Add SUSE Package Hub
# byacc is only in packagehub
SUSEConnect -p PackageHub/15.4/x86_64
#-------------------------------------------------------------------

#
## SLES HPC ship with many HPC packages already, so no need to build it - simple install is enough
#
# as the default cloud image does only install parts of the HPC toolchain we use the pattern
zypper install -y --type pattern hpc_libraries

## Lmod is an advanced environment module system that allows the installation of multiple versions of a program or shared library, and helps configure the system environment for the use of a specific version.
## the modulefile path is /usr/share/lmod/modulefiles
zypper install lua-lmod
source /usr/share/lmod/lmod/init/bash

#
zypper install -y \
    numactl \
    byacc \
    gtk2 \
    atk \
    m4 \
    tcsh \
    gcc-fortran \
    elfutils \
    kernel-macros \
    binutils \
    kernel-headers \
    kernel-source \
    nfs-utils \
    fuse \
    cmake \
    libarchive13 \
    libsecret-1-0 \
    libnuma-devel \
    libibverbs-utils \
    rdma-core \
    ibutils \
    infiniband-diags \
    perftest \
    mstflint \
    bzip2 \
    vim-data \
    clone-master-clean-up \
    insserv-compat \
    rpm-build \
    python3-devel\
    patch \
    python-rpm-macros \
    lshw

# the ibdev2netdev is only in the external mellanox package, so we do not have it with inbox drivers
wget https://raw.githubusercontent.com/Mellanox/container_scripts/master/ibdev2netdev
mv ibdev2netdev /usr/local/bin
chmod +x /usr/local/bin/ibdev2netdev

# Install azcopy tool
# To copy blobs or files to or from a storage account.
# actual is 10.16.1
AZCOPY_VERSION="10.16.1"
AZCOPY_URL="https://aka.ms/downloadazcopy-v10-linux"

# not accessible anymore at this blob - its private now
# wget https://azcopyvnextrelease.blob.core.windows.net/release20210920/azcopy_linux_se_amd64_10.12.2.tar.gz

# public download
wget -O azcopy_linux_amd64_${AZCOPY_VERSION}.tar.gz ${AZCOPY_URL}
tar -xvf azcopy_linux_amd64_${AZCOPY_VERSION}.tar.gz

# copy the azcopy to the bin path - better would be /usr/local/bin
pushd azcopy_linux_amd64_${AZCOPY_VERSION}
cp azcopy /usr/local/bin/
popd

# Allow execute permissions
chmod +x /usr/local/bin/azcopy
$COMMON_DIR/write_component_version.sh "azcopy" ${AZCOPY_VERSION}