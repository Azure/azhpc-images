#!/bin/bash
set -ex

# Install pre-reqs and development tools
yum groupinstall -y "Development Tools"
yum install -y numactl \
    numactl-devel \
    libxml2-devel \
    byacc \
    environment-modules \
    python-devel \
    python-setuptools \
    gtk2 \
    atk \
    cairo \
    tcl \
    tk \
    m4 \
    texinfo \
    glibc-devel \
    glibc-static \
    libudev-devel \
    binutils \
    binutils-devel \
    selinux-policy-devel \
    kernel-headers \
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
    subunit \
    subunit-devel

## Install dkms from the EPEL repository
wget -r --no-parent -A "dkms-*.el7.noarch.rpm" https://dl.fedoraproject.org/pub/epel/7/x86_64/Packages/d/ 
yum localinstall ./dl.fedoraproject.org/pub/epel/7/x86_64/Packages/d/dkms-*.el7.noarch.rpm -y

## Install jq Utility
# Download dependency libonig.so for jq
wget -r --no-parent -A "oniguruma-*.el7.x86_64.rpm" https://dl.fedoraproject.org/pub/epel/7/x86_64/Packages/o/
yum localinstall ./dl.fedoraproject.org/pub/epel/7/x86_64/Packages/o/oniguruma-*.el7.x86_64.rpm -y
# Download jq utility
wget -r --no-parent -A "jq-*.el7.x86_64.rpm" https://dl.fedoraproject.org/pub/epel/7/x86_64/Packages/j/
yum localinstall ./dl.fedoraproject.org/pub/epel/7/x86_64/Packages/j/jq-*.el7.x86_64.rpm -y

# Remove rpm files
rm -rf ./dl.fedoraproject.org/

# Install azcopy tool 
# To copy blobs or files to or from a storage account.
wget https://azhpcstor.blob.core.windows.net/azhpc-images-store/azcopy_linux_se_amd64_10.12.2.tar.gz
tar -xvf azcopy_linux_se_amd64_10.12.2.tar.gz

# copy the azcopy to the bin path
pushd azcopy_linux_se_amd64_10.12.2
cp azcopy /usr/bin/
popd

# Allow execute permissions
chmod +x /usr/bin/azcopy

# remove tarball from azcopy
rm -rf *.tar.gz
