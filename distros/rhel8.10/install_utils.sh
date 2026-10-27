#!/bin/bash
set -ex

source ${UTILS_DIR}/utilities.sh

# Install the "Microsoft TLS RSA Root G2" trust anchor before any HTTPS
# calls to Microsoft endpoints.
$COMPONENT_DIR/install_microsoft_tls_root_g2.sh

curl -fsSL https://packages.microsoft.com/config/rhel/8/prod.repo > ./microsoft-prod.repo
sed -i '/^\[/a module_hotfixes=1' ./microsoft-prod.repo
cp ./microsoft-prod.repo /etc/yum.repos.d/

dnf install -y dnf-plugins-core
dnf config-manager --set-enabled codeready-builder-for-rhel-8-x86_64-rhui-rpms

# Install EPEL repository
dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm

# Install Kernel dependencies
KERNEL=$(uname -r)
dnf install -y kernel-devel-${KERNEL} kernel-headers-${KERNEL} kernel-modules-extra-${KERNEL}

dnf install -y wget \
               net-tools \
               python3.12

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
    json-c-devel \
    dos2unix \
    azcopy \
    mdadm

dnf install -y environment-modules

## Install kernel-abi-stablelists (needed by DOCA)
dnf install -y kernel-abi-stablelists

## Install EPEL packages (pssh, dkms, subunit, subunit-devel)
dnf install -y pssh dkms subunit subunit-devel

git clone --depth 1 https://github.com/Azure/azure-vm-utils.git /tmp/azure-vm-utils
pushd /tmp/azure-vm-utils
cmake -S . -B build -DENABLE_TESTS=0
cmake --build build
cmake --install build
popd
rm -rf /tmp/azure-vm-utils

if sku_uses_ipoib; then
    echo ib_ipoib | sudo tee /etc/modules-load.d/ib_ipoib.conf
fi

# copy kvp client file
$COMPONENT_DIR/copy_kvp_client.sh

# copy torset tool
$COMPONENT_DIR/copy_torset_tool.sh
