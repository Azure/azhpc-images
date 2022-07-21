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
    https://dl.fedoraproject.org/pub/epel/7/x86_64/Packages/d/dkms-3.0.5-1.el7.noarch.rpm \
    rpm-build \
    make \
    check \
    check-devel \
    subunit \
    subunit-devel
    
# Install azcopy tool 
# To copy blobs or files to or from a storage account.
wget https://azcopyvnextrelease.blob.core.windows.net/release20210920/azcopy_linux_se_amd64_10.12.2.tar.gz
tar -xvf azcopy_linux_se_amd64_10.12.2.tar.gz

# copy the azcopy to the bin path
pushd azcopy_linux_se_amd64_10.12.2
cp azcopy /usr/bin/
popd

# Allow execute permissions
chmod +x /usr/bin/azcopy
