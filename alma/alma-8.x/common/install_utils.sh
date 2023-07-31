#!/bin/bash
set -ex

# Install Kernel dependencies
dnf install -y https://repo.almalinux.org/vault/8.7/BaseOS/x86_64/os/Packages/kernel-devel-$KERNEL.rpm \
    https://repo.almalinux.org/vault/8.7/BaseOS/x86_64/os/Packages/kernel-headers-$KERNEL.rpm \
    https://repo.almalinux.org/vault/8.7/BaseOS/x86_64/os/Packages/kernel-modules-extra-$KERNEL.rpm

# Install Python 3.8
dnf install -y python3.8
ln -fs /usr/bin/python3.8 /usr/bin/python3

# install pssh
pssh_metadata=$(jq -r '.pssh."'"$DISTRIBUTION"'"' <<< $COMPONENT_VERSIONS)
pssh_version=$(jq -r '.version' <<< $pssh_metadata)
pssh_sha256=$(jq -r '.sha256' <<< $pssh_metadata)
pssh_download_url="https://dl.fedoraproject.org/pub/epel/8/Everything/aarch64/Packages/p/pssh-$pssh_version.el8.noarch.rpm"
$COMMON_DIR/download_and_verify.sh $pssh_download_url $pssh_sha256

dnf install -y  pssh-$pssh_version.el8.noarch.rpm
rm -f pssh-$pssh_version.el8.noarch.rpm

dnf install -y python3-devel \
    gtk2 \
    glibc-devel \
    libudev-devel \
    selinux-policy-devel \
    fuse-libs \
    libnl3-devel \
    rpm-build \
    make \
    kernel-rpm-macros \
    tk \
    binutils-devel \
    munge \
    numactl-devel \
    environment-modules
    
## Disable kernel updates
echo "exclude=kernel* kmod*" | tee -a /etc/dnf/dnf.conf

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
rm -rf ./repo.almalinux.org/

# Install common dependencies
$COMMON_DIR/install_utils.sh

# copy kvp client file
$COMMON_DIR/copy_kvp_client.sh
