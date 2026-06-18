#!/bin/bash
set -ex

source ${UTILS_DIR}/utilities.sh

# Install the "Microsoft TLS RSA Root G2" trust anchor before any HTTPS
# calls to Microsoft endpoints.
$COMPONENT_DIR/install_microsoft_tls_root_g2.sh

# Setup microsoft packages repository for moby
# Download the repository configuration package
curl https://packages.microsoft.com/config/rhel/9/prod.repo > ./microsoft-prod.repo
# Copy the generated list to the sources.list.d directory
cp ./microsoft-prod.repo /etc/yum.repos.d/

dnf repolist
dnf update -y

# Install Kernel dependencies
KERNEL=$(uname -r)
dnf install -y kernel-devel-matched-${KERNEL} kernel-devel-${KERNEL} kernel-headers-${KERNEL} kernel-modules-extra-${KERNEL}

dnf install -y wget \
               net-tools \
               python3.12

alternatives --install /usr/bin/python3 python3 /usr/bin/python3.9 20
alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 10
alternatives --set python3 /usr/bin/python3.9

# Install EPEL repository
dnf install -y epel-release

dnf -y install dnf-plugins-core
dnf config-manager --set-enabled crb

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
    azure-vm-utils \
    dos2unix \
    azcopy \
    mdadm

# Install environment-modules 5.0.1
wget https://repo.almalinux.org/vault/9.4/BaseOS/x86_64/os/Packages/environment-modules-5.3.0-1.el9.x86_64.rpm
dnf install -y environment-modules-5.3.0-1.el9.x86_64.rpm
rm -f environment-modules-5.3.0-1.el9.x86_64.rpm

## Install kernel-abi-stablelists (needed by DOCA)
dnf install -y kernel-abi-stablelists

## Install EPEL packages (pssh, dkms, subunit, subunit-devel)
dnf install -y pssh dkms subunit subunit-devel

echo ib_ipoib | sudo tee /etc/modules-load.d/ib_ipoib.conf

# copy kvp client file
$COMPONENT_DIR/copy_kvp_client.sh

# copy torset tool
$COMPONENT_DIR/copy_torset_tool.sh
