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
rpm --import $INTEL_PUBKEY_URI
# add repository
zypper -n addrepo -f -g $INTEL_REPO_URI oneAPI
# fetch key
zypper --non-interactive --gpg-auto-import-keys refresh oneAPI
# disable auto-refresh for the repo (mr -F)
zypper --non-interactive modifyrepo --no-refresh oneAPI

# list all packages
# sudo -E zypper pa -ir oneAPI
#-------------------------------------------------------------------

#-------------------------------------------------------------------
# Nvidia provide certified packages for SLES 15, so we only need to add the repositories and install the packages
#-------------------------------------------------------------------
# import cuda signing key
rpm --import $CUDA_PUBKEY_URI
# CUDA driver (nvidia provides a repo file)
zypper addrepo -f -g $CUDA_REPO_URI
# fetch key
zypper --non-interactive --gpg-auto-import-keys refresh cuda-sles${SLE_MAJOR}-x86_64

#-------------------------------------------------------------------
# Container Repository
#-------------------------------------------------------------------
# Docker is shipped with SLES by default
# with SLES HPC we need to enable the Container repository
SUSEConnect -p sle-module-containers/${SLE_DOTV}/x86_64

#-------------------------------------------------------------------
# nvidia container repo
#-------------------------------------------------------------------
# see https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html
# Check https://nvidia.github.io/libnvidia-container
zypper addrepo -f -g $NVIDIA_CONTAINER_REPO_URI
# fetch key
zypper --non-interactive --gpg-auto-import-keys refresh libnvidia-container

#-------------------------------------------------------------------
# Add SUSE Package Hub
# byacc is only in packagehub
SUSEConnect -p PackageHub/${SLE_DOTV}/x86_64
#-------------------------------------------------------------------

#
## SLES HPC ship with many HPC packages already, so no need to build it - simple install is enough
#
# Install base compiler (this will pull in Lmod as well)
zypper in -y gnu-compilers-hpc

## Lmod is an advanced environment module system that allows the installation of multiple versions of a program or shared library, and helps configure the system environment for the use of a specific version.
## the modulefile path is /usr/share/lmod/modulefiles
source /usr/share/lmod/lmod/init/bash

#
# If you run kernel-default remove "-azure" from the kernel package names below
#
zypper install -y \
    numactl \
    byacc \
    atk \
    m4 \
    binutils \
    kernel-azure-devel = ${KERNEL_VERSION} \
    kernel-source-azure = ${KERNEL_VERSION} \
    fuse \
    cmake \
    libarchive13 \
    libsecret-1-0 \
    libnuma-devel \
    libibverbs-utils \
    ibutils \
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
    nfs-client \
    jq

# Install azcopy tool
## To copy blobs or files to or from a storage account.
wget ${AZCOPY_DOWNLOAD_URL}
tar -xvf ${AZTARBALL}
## copy the azcopy to the bin path - better would be ${LOCALBIN}
pushd azcopy_linux_amd64_${AZVERSION}
mv azcopy ${LOCALBIN}
popd
chmod +x ${LOCALBIN}/azcopy
## remove azcopy tarball
rm -rf *.tar.gz
