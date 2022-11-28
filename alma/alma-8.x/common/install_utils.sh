#!/bin/bash
set -ex

# Install Kernel dependencies
KERNEL=( $(rpm -q kernel | sed 's/kernel\-//g') )
yum install -y https://repo.almalinux.org/almalinux/8.6/BaseOS/x86_64/os/Packages/kernel-devel-${KERNEL}.rpm \
    https://repo.almalinux.org/almalinux/8.6/BaseOS/x86_64/os/Packages/kernel-headers-${KERNEL}.rpm \
    https://repo.almalinux.org/almalinux/8.6/BaseOS/x86_64/os/Packages/kernel-modules-extra-${KERNEL}.rpm

# Install Python 3.8
yum install -y python3.8
ln -fs /usr/bin/python3.8 /usr/bin/python3

# Install pre-reqs and development tools
yum groupinstall -y "Development Tools"
yum install -y numactl \
    numactl-devel \
    libxml2-devel \
    byacc \
    environment-modules \
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
    perl

## Disable kernel updates
echo "exclude=kernel* kmod*" | tee -a /etc/dnf/dnf.conf

## Install dkms from the EPEL repository
wget -r --no-parent -A "dkms-*.el8.noarch.rpm" https://dl.fedoraproject.org/pub/epel/8/Everything/x86_64/Packages/d/
yum localinstall ./dl.fedoraproject.org/pub/epel/8/Everything/x86_64/Packages/d/dkms-*.el8.noarch.rpm -y

## Install subunit and subunit-devel from EPEL repository
wget -r --no-parent -A "subunit-*.el8.x86_64.rpm" https://dl.fedoraproject.org/pub/epel/8/Everything/x86_64/Packages/s/
yum localinstall ./dl.fedoraproject.org/pub/epel/8/Everything/x86_64/Packages/s/subunit-[0-9].*.el8.x86_64.rpm -y
yum localinstall ./dl.fedoraproject.org/pub/epel/8/Everything/x86_64/Packages/s/subunit-devel-[0-9].*.el8.x86_64.rpm -y

# Download jq utility
wget -r --no-parent -A "jq-*.el8.x86_64.rpm" https://repo.almalinux.org/almalinux/8/AppStream/x86_64/os/Packages/
yum localinstall ./repo.almalinux.org/almalinux/8/AppStream/x86_64/os/Packages/jq-*.el8.x86_64.rpm -y

# Remove rpm files
rm -rf ./dl.fedoraproject.org/
rm -rf ./repo.almalinux.org/

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
