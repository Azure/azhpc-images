#!/bin/bash
set -ex

source ${UTILS_DIR}/utilities.sh

# Install Python 3.8
dnf install -y python3.8
ln -fs /usr/bin/python3.8 /usr/bin/python3

# Install EPEL repository
dnf install -y epel-release

dnf install -y dnf-plugins-core

# Install pre-reqs and development tools
dnf groupinstall -y "Development Tools"
dnf install -y numactl \
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
    azcopy \
    dos2unix

# Install environment-modules 5.0.1
wget https://repo.almalinux.org/vault/9.1/BaseOS/x86_64/os/Packages/environment-modules-5.0.1-1.el9.x86_64.rpm
dnf install -y environment-modules-5.0.1-1.el9.x86_64.rpm
rm -f environment-modules-5.0.1-1.el9.x86_64.rpm

## Install kernel-abi-stablelists (needed by DOCA) before locking kernel packages
dnf install -y kernel-abi-stablelists

## Disable kernel updates
dnf versionlock add "kernel*" "kmod*" "shim*" "grub2*"

## Install EPEL packages (pssh, dkms, subunit, subunit-devel)
dnf install -y pssh dkms subunit subunit-devel

# copy kvp client file
$COMMON_DIR/copy_kvp_client.sh

# copy torset tool
$COMMON_DIR/copy_torset_tool.sh
