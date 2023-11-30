#!/bin/bash
set -ex

#-------------------------------------------------------------------
# Container Repository
#-------------------------------------------------------------------
# Docker is shipped with SLES by default
# with SLE HPC we need to enable the Container repository
SUSEConnect -p sle-module-containers/${SLE_DOTV}/x86_64

#-------------------------------------------------------------------
# Add SUSE Package Hub
# byacc is only in packagehub
SUSEConnect -p PackageHub/${SLE_DOTV}/x86_64
#-------------------------------------------------------------------

#-------------------------------------------------------------------
# Nvidia provide certified packages for SLES 15, so we only need to add the repositories and install the packages
# add the repo key separately beforehand.
SUSEConnect -p sle-module-NVIDIA-compute/${SLE_MAJOR}/x86_64 --gpg-auto-import-keys
#-------------------------------------------------------------------

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
# delete if exists
zypper -n rr oneAPI &>/dev/null || :
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
# Nvidia container repo
#-------------------------------------------------------------------
# see https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html
# Check https://nvidia.github.io/libnvidia-container
zypper --non-interactive rr libnvidia-container &>/dev/null || :
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
# Install base compiler (this will pull in packages for HPC and Lmod as well)
zypper --non-interactive in -y gnu-compilers-hpc-devel

#
# If you run kernel-default remove "-azure" from the kernel package names below
#
zypper install -y \
    numactl \
    byacc \
    atk \
    m4 \
    ${KERNEL_VERSION:+kernel-azure-devel = ${KERNEL_VERSION}} \
    ${KERNEL_VERSION:+kernel-source-azure = ${KERNEL_VERSION}} \
    binutils \
    fuse \
    cmake \
    libarchive13 \
    libsecret-1-0 \
    libnuma-devel \
    libibverbs-utils \
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
    jq \
    rdma-core-devel \
    wget

# Install azcopy tool
## To copy blobs or files to or from a storage account.
wget ${AZCOPY_DOWNLOAD_URL}
tar -xvf ${AZTARBALL}
## copy the azcopy to the bin path - better would be ${LOCALBIN}
mv azcopy_linux_amd64_${AZVERSION}/azcopy ${LOCALBIN}
chmod +x ${LOCALBIN}/azcopy
$COMMON_DIR/write_component_version.sh "azcopy" ${AZCOPY_VERSION}
## remove azcopy tarball and directory
rm -rf *.tar.gz azcopy_linux_amd64_${AZVERSION}

