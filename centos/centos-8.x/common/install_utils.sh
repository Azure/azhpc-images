#!/bin/bash
set -ex

# CentOS 8 being EOL needs to read/ update package list from vault.centos.org
# Reference - https://forums.centos.org/viewtopic.php?t=78708
sed -i 's|baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-*
yum clean all

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
