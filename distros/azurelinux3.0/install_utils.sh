#!/bin/bash
set -ex

source ${UTILS_DIR}/utilities.sh

# Install the "Microsoft TLS RSA Root G2" trust anchor before any HTTPS
# calls to Microsoft endpoints.
$COMPONENT_DIR/install_microsoft_tls_root_g2.sh

# Install Kernel dependencies
if [ "$ARCHITECTURE" = "aarch64" ]; then
    dnf install -y kernel-hwe-devel-$(uname -r) \
                kernel-hwe-drivers-gpu-$(uname -r) \
                kernel-headers

else
    dnf install -y kernel-headers-$(uname -r) \
                kernel-devel-$(uname -r) \
                kernel-drivers-gpu-$(uname -r) \
                dkms
fi

# Install Python 3.12
dnf install -y python

# install pssh
dnf install -y pssh

# tk package is present in extended repo
dnf install -y azurelinux-repos-extended

dnf repolist --refresh

# Install pre-reqs and development tools
# dnf groupinstall -y "Development Tools"
dnf install -y numactl \
    numactl-devel \
    libxml2-devel \
    byacc \
    python3-devel \
    python3-setuptools \
    python3-pip \
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
    munge \
    pam-devel \
    ed \
    selinux-policy-devel \
    nfs-utils \
    fuse-libs \
    libpciaccess \
    cmake \
    bison \
    libnl3-devel \
    libsecret \
    rpm-build \
    rpmdevtools \
    environment-modules \
    make \
    check \
    check-devel \
    lsof \
    azurelinux-rpm-macros \
    tcsh \
    gcc-gfortran \
    perl \
    json-c-devel \
    pciutils \
    dnf-plugins-core \
    vim \
    nano \
    device-mapper-multipath \
    mdadm \
    ca-certificates-tools \
    git \
    gtest-devel \
    gmock-devel \
    hwloc-devel \
    rsyslog \
    dos2unix \
    azcopy

# Enable kernel log messages to file as per HPC requirement.
sed -i 's/^\#kern\.\*.*/kern\.\*                                \-\/var\/log\/kern.log/' /etc/rsyslog.conf
# Add kern.log from rsyslog to logrotate
sed -i 's#/var/log/maillog#/var/log/maillog\n/var/log/kern.log#' /etc/logrotate.d/rsyslog

## Install dkms
dnf install -y dkms

## Install subunit and subunit-devel
dnf install -y subunit
dnf install -y subunit-devel

## Install libmd and libmd-devel 
dnf install -y libmd
dnf install -y libmd-devel

# Install azure-vm-utils from source (upstream package for AZL3 is too outdated right now, see https://github.com/microsoft/azurelinux/issues/15661)
git clone --depth 1 https://github.com/Azure/azure-vm-utils.git /tmp/azure-vm-utils
pushd /tmp/azure-vm-utils
mkdir build && cd build
cmake -DENABLE_TESTS=0 ..
make
make install
popd
rm -rf /tmp/azure-vm-utils

# copy kvp client file
$COMPONENT_DIR/copy_kvp_client.sh

# copy torset tool
$COMPONENT_DIR/copy_torset_tool.sh

# Create alias for "ls -l"
echo "alias ll='ls -l'" | tee -a /etc/bash.bashrc

