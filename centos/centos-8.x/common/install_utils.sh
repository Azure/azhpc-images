#!/bin/bash
set -ex

# Install pre-reqs and development tools
yum groupinstall -y "Development Tools"
yum install -y numactl \
    numactl-devel \
    libxml2-devel \
    byacc \
    environment-modules \
    gtk2 \
    atk \
    cairo \
    tcl \
    tk \
    m4 \
    tcsh \
    gcc-gfortran \
    python36-devel \
    elfutils-libelf-devel \
    kernel-rpm-macros \
    glibc-devel \
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
    libarchive \
    libsecret

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
