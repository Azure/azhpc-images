#!/bin/bash
set -ex

source ${UTILS_DIR}/utilities.sh

# Setup microsoft packages repository for moby
# Download the repository configuration package
curl https://packages.microsoft.com/config/rhel/8/prod.repo > ./microsoft-prod.repo
# Copy the generated list to the sources.list.d directory
sudo cp ./microsoft-prod.repo /etc/yum.repos.d/

dnf repolist

# Install wget as Rocky Linux 8.10 does not have it by default
sudo dnf install -y wget

# Install net-tools as Rocky Linux 8.10 does not have ifconfig by default
sudo dnf install -y net-tools

# Install jq for JSON parsing (needed by utilities.sh)
sudo dnf install -y jq

# Install Kernel dependencies
KERNEL=$(uname -r)

# Download and install kernel packages using dnf to resolve dependencies
wget --retry-connrefused --tries=3 --waitretry=5 https://dl.rockylinux.org/pub/rocky/8.10/BaseOS/x86_64/os/Packages/k/kernel-devel-${KERNEL}.rpm
wget --retry-connrefused --tries=3 --waitretry=5 https://dl.rockylinux.org/pub/rocky/8.10/BaseOS/x86_64/os/Packages/k/kernel-headers-${KERNEL}.rpm
wget --retry-connrefused --tries=3 --waitretry=5 https://dl.rockylinux.org/pub/rocky/8.10/BaseOS/x86_64/os/Packages/k/kernel-modules-extra-${KERNEL}.rpm || true

# Use dnf localinstall to automatically resolve and install dependencies (e.g., perl-interpreter)
sudo dnf install -y kernel-devel-${KERNEL}.rpm kernel-headers-${KERNEL}.rpm || true
# kernel-modules-extra may not exist for all kernels, so install separately with || true
sudo dnf install -y kernel-modules-extra-${KERNEL}.rpm 2>/dev/null || true

rm -f kernel-devel-${KERNEL}.rpm kernel-headers-${KERNEL}.rpm kernel-modules-extra-${KERNEL}.rpm

# install pssh
pssh_metadata=$(get_component_config "pssh")
pssh_version=$(jq -r '.version' <<< $pssh_metadata)
pssh_sha256=$(jq -r '.sha256' <<< $pssh_metadata)
pssh_download_url="https://dl.fedoraproject.org/pub/epel/8/Everything/x86_64/Packages/p/pssh-$pssh_version.el8.noarch.rpm"
download_and_verify $pssh_download_url $pssh_sha256

dnf install -y  pssh-$pssh_version.el8.noarch.rpm
rm -f pssh-$pssh_version.el8.noarch.rpm

# Install pre-reqs and development tools
dnf groupinstall -y "Development Tools"
dnf install -y numactl \
    numactl-devel \
    libxml2-devel \
    byacc \
    bc \
    python3.11-pyyaml \
    gtk2 \
    atk \
    cairo \
    tcl \
    tk \
    m4 \
    glibc-devel \
    libudev-devel \
    binutils \
    binutils-devel \
    selinux-policy-devel \
    nfs-utils \
    fuse-libs \
    libpciaccess \
    cmake \
    libnl3-devel \
    libsecret \
    rpm-build \
    make \
    check \
    check-devel \
    lsof \
    kernel-rpm-macros \
    tcsh \
    gcc-gfortran \
    perl \
    libdrm-devel \
    dos2unix \
    azcopy \
    lvm2

# Install environment-modules 4.5.2
wget https://dl.rockylinux.org/pub/rocky/8.10/BaseOS/x86_64/os/Packages/e/environment-modules-4.5.2-4.el8.x86_64.rpm
dnf install -y environment-modules-4.5.2-4.el8.x86_64.rpm
rm -f environment-modules-4.5.2-4.el8.x86_64.rpm

## Disable kernel updates (but not kernel-rpm-macros and other tools)
echo "exclude=kernel kernel-core kernel-modules kernel-devel kernel-headers kernel-modules-extra" | tee -a /etc/dnf/dnf.conf

# Disable dependencies on kernel core
sed -i "$ s/$/ shim*/" /etc/dnf/dnf.conf
sed -i "$ s/$/ grub2*/" /etc/dnf/dnf.conf

## Install dkms from the EPEL repository
wget -r --no-parent -A "dkms-*.el8.noarch.rpm" https://dl.fedoraproject.org/pub/epel/8/Everything/x86_64/Packages/d/
dnf localinstall ./dl.fedoraproject.org/pub/epel/8/Everything/x86_64/Packages/d/dkms-*.el8.noarch.rpm -y

## Install subunit and subunit-devel from EPEL repository
wget -r --no-parent -A "subunit-*.el8.x86_64.rpm" https://dl.fedoraproject.org/pub/epel/8/Everything/x86_64/Packages/s/
dnf localinstall ./dl.fedoraproject.org/pub/epel/8/Everything/x86_64/Packages/s/subunit-[0-9].*.el8.x86_64.rpm -y
dnf localinstall ./dl.fedoraproject.org/pub/epel/8/Everything/x86_64/Packages/s/subunit-devel-[0-9].*.el8.x86_64.rpm -y

# Remove rpm files
rm -rf ./dl.fedoraproject.org/
rm -rf ./dl.rockylinux.org/

echo ib_ipoib | sudo tee /etc/modules-load.d/ib_ipoib.conf

# copy kvp client file
$COMPONENT_DIR/copy_kvp_client.sh

# copy torset tool
$COMPONENT_DIR/copy_torset_tool.sh
