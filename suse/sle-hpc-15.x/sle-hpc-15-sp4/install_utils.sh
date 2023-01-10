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
    lshw \
    autoconf \
    automake \
    libtool \
    rdma-core-devel

# Install azcopy tool
# To copy blobs or files to or from a storage account.
VERSION="10.16.2"
RELEASE_TAG="release20221108"
TARBALL="azcopy_linux_amd64_${VERSION}.tar.gz"
AZCOPY_DOWNLOAD_URL="https://azcopyvnext.azureedge.net/${RELEASE_TAG}/${TARBALL}"
AZCOPY_FOLDER=$(basename ${AZCOPY_DOWNLOAD_URL} .tgz)
wget ${AZCOPY_DOWNLOAD_URL}
tar -xvf ${TARBALL}

# copy the azcopy to the bin path
pushd azcopy_linux_amd64_${VERSION}
cp azcopy /usr/bin/
popd

# Allow execute permissions
chmod +x /usr/bin/azcopy

# remove tarball from azcopy
rm -rf *.tar.gz
