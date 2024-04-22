#!/bin/bash
set -ex

# Setup Mariner Extended packages repo
curl -s -L https://packages.microsoft.com/cbl-mariner/2.0/prod/extended/x86_64/config.repo  | tee /etc/yum.repos.d/mariner-extended-prod.repo

# Setup microsoft packages repository for moby
# Download the repository configuration package
# curl -s -L https://packages.microsoft.com/config/rhel/8/prod.repo | tee /etc/yum.repos.d/microsoft-prod.repo

tdnf repolist

# Install Kernel dependencies
tdnf install -y kernel-headers-$(uname -r) \
                kernel-devel-$(uname -r) # Needed for MOFED all of a sudden

# Install Python 3
tdnf install -y python3

# install pssh
# pssh_metadata=$(jq -r '.pssh."'"$DISTRIBUTION"'"' <<< $COMPONENT_VERSIONS)
# pssh_version=$(jq -r '.version' <<< $pssh_metadata)
# pssh_sha256=$(jq -r '.sha256' <<< $pssh_metadata)
# pssh_download_url="https://dl.fedoraproject.org/pub/epel/8/Everything/aarch64/Packages/p/pssh-$pssh_version.el8.noarch.rpm"
# $COMMON_DIR/download_and_verify.sh $pssh_download_url $pssh_sha256

# tdnf install -y  pssh-$pssh_version.el8.noarch.rpm
# rm -f pssh-$pssh_version.el8.noarch.rpm

tdnf install -y python3-devel \
    gtk2 \
    glibc-devel \
    libudev-devel \
    selinux-policy-devel \
    fuse-libs \
    libnl3-devel \
    rpm-build \
    rpmdevtools \
    make \
    cmake \
    mariner-rpm-macros \
    tk \
    binutils-devel \
    munge \
    numactl-devel \
    environment-modules \
    pam-devel \
    ed \
    pciutils \
    vim \
    dnf-plugins-core \
    check \
    python3-pip \
    gfortran \
    lsb-release
   
## Disable kernel updates
#echo "exclude=kernel* kmod*" | tee -a /etc/dnf/dnf.conf

# Disable dependencies on kernel core
#sed -i "$ s/$/ shim*/" /etc/dnf/dnf.conf
#sed -i "$ s/$/ grub2*/" /etc/dnf/dnf.conf

## Install dkms from the EPEL repository
wget -r --no-parent -A "dkms-*.el8.noarch.rpm" https://dl.fedoraproject.org/pub/epel/8/Everything/x86_64/Packages/d/
dnf localinstall -y ./dl.fedoraproject.org/pub/epel/8/Everything/x86_64/Packages/d/dkms-*.el8.noarch.rpm

## Install subunit and subunit-devel from EPEL repository
wget -r --no-parent -A "subunit-*.el8.x86_64.rpm" https://dl.fedoraproject.org/pub/epel/8/Everything/x86_64/Packages/s/
dnf localinstall -y ./dl.fedoraproject.org/pub/epel/8/Everything/x86_64/Packages/s/subunit-[0-9].*.el8.x86_64.rpm
dnf localinstall -y ./dl.fedoraproject.org/pub/epel/8/Everything/x86_64/Packages/s/subunit-devel-[0-9].*.el8.x86_64.rpm

## Install libmd and libmd-devel from EPEL repository
wget -r --no-parent -A "libmd-*.el8.x86_64.rpm" https://dl.fedoraproject.org/pub/epel/8/Everything/x86_64/Packages/l/
dnf localinstall -y ./dl.fedoraproject.org/pub/epel/8/Everything/x86_64/Packages/l/libmd-[0-9].*.el8.x86_64.rpm
dnf localinstall -y ./dl.fedoraproject.org/pub/epel/8/Everything/x86_64/Packages/l/libmd-devel-[0-9].*.el8.x86_64.rpm

# Remove rpm files
rm -rf ./dl.fedoraproject.org/

# copy kvp client file
$COMMON_DIR/copy_kvp_client.sh

rm -rf ./packages.microsoft.com/

# Create alias for "ls -l"
echo "alias ll='ls -l'" | tee -a /etc/bash.bashrc
