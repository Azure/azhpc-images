#!/bin/bash
set -ex

source ${UTILS_DIR}/utilities.sh

# Setup microsoft packages repository for moby
# Download the repository configuration package
curl https://packages.microsoft.com/config/rhel/8/prod.repo > ./microsoft-prod.repo
# Copy the generated list to the sources.list.d directory
cp ./microsoft-prod.repo /etc/yum.repos.d/

yum repolist

# Install Kernel dependencies
KERNEL=( $(rpm -q kernel | sed 's/kernel\-//g') )

yum install -y https://repo.almalinux.org/almalinux/8.10/BaseOS/x86_64/os/Packages/kernel-devel-${KERNEL}.rpm \
    https://repo.almalinux.org/almalinux/8.10/BaseOS/x86_64/os/Packages/kernel-headers-${KERNEL}.rpm \
    https://repo.almalinux.org/almalinux/8.10/BaseOS/x86_64/os/Packages/kernel-modules-extra-${KERNEL}.rpm

yum install -y kernel-mft-dkms

# Install wget as AlmaLinux 8.10 does not have it by default
sudo yum install -y wget

# Install net-tools as AlmaLinux 8.10 does not have ifconfig by default
sudo yum install -y net-tools

# install pssh
pssh_metadata=$(get_component_config "pssh")
pssh_version=$(jq -r '.version' <<< $pssh_metadata)
pssh_sha256=$(jq -r '.sha256' <<< $pssh_metadata)
pssh_download_url="https://dl.fedoraproject.org/pub/epel/8/Everything/aarch64/Packages/p/pssh-$pssh_version.el8.noarch.rpm"
download_and_verify $pssh_download_url $pssh_sha256

yum install -y  pssh-$pssh_version.el8.noarch.rpm
rm -f pssh-$pssh_version.el8.noarch.rpm

# Install pre-reqs and development tools
yum groupinstall -y "Development Tools"
yum install -y numactl \
    numactl-devel \
    libxml2-devel \
    byacc \
    python3-devel \
    python3-setuptools \
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
    dos2unix \
    azcopy

# Install environment-modules 5.0.1
wget https://repo.almalinux.org/vault/9.1/BaseOS/x86_64/os/Packages/environment-modules-5.0.1-1.el9.x86_64.rpm
yum install -y environment-modules-5.0.1-1.el9.x86_64.rpm
rm -f environment-modules-5.0.1-1.el9.x86_64.rpm

## Disable kernel updates
echo "exclude=kernel*" | tee -a /etc/dnf/dnf.conf

# Disable dependencies on kernel core
sed -i "$ s/$/ shim*/" /etc/dnf/dnf.conf
sed -i "$ s/$/ grub2*/" /etc/dnf/dnf.conf

## Install dkms from the EPEL repository
wget -r --no-parent -A "dkms-*.el8.noarch.rpm" https://dl.fedoraproject.org/pub/epel/8/Everything/x86_64/Packages/d/
yum localinstall ./dl.fedoraproject.org/pub/epel/8/Everything/x86_64/Packages/d/dkms-*.el8.noarch.rpm -y

## Install subunit and subunit-devel from EPEL repository
wget -r --no-parent -A "subunit-*.el8.x86_64.rpm" https://dl.fedoraproject.org/pub/epel/8/Everything/x86_64/Packages/s/
yum localinstall ./dl.fedoraproject.org/pub/epel/8/Everything/x86_64/Packages/s/subunit-[0-9].*.el8.x86_64.rpm -y
yum localinstall ./dl.fedoraproject.org/pub/epel/8/Everything/x86_64/Packages/s/subunit-devel-[0-9].*.el8.x86_64.rpm -y

# Remove rpm files
rm -rf ./dl.fedoraproject.org/
rm -rf ./repo.almalinux.org/

# copy kvp client file
$COMPONENT_DIR/copy_kvp_client.sh

# copy torset tool
$COMPONENT_DIR/copy_torset_tool.sh
