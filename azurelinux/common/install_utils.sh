#!/bin/bash
set -ex

echo "Variable name in install_utils for utilities"
echo ${COMMON_DIR}

source ${COMMON_DIR}/utilities.sh

# Install Kernel dependencies
tdnf install -y kernel-headers-$(uname -r) \
                kernel-devel-$(uname -r) \
                kernel-drivers-gpu-$(uname -r)

# Install Python 3.12
tdnf install -y python
# ln -fs /usr/bin/python3.8 /usr/bin/python3

# install pssh
tdnf install -y pssh

# tk package is present in extended repo
tdnf install -y azurelinux-repos-extended

# Install pre-reqs and development tools
# tdnf groupinstall -y "Development Tools"
tdnf install -y numactl \
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
    libnl3-devel \
    libsecret \
    rpm-build \
    rpmdevtools \
    environment-modules \
    make \
    cmake \
    check \
    check-devel \
    lsof \
    azurelinux-rpm-macros \
    tcsh \
    gcc-gfortran \
    perl \
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

# Disable kernel updates
echo "exclude=kernel* kmod*" | tee -a /etc/dnf/dnf.conf
# Since tdnf is the default package manager and
# because /etc/tdnf/tdnf.conf does not recongnize
# exclude option adding a kernel package lock file
# https://github.com/vmware/tdnf/wiki/Configuration-Options#package-locks
mkdir -p /etc/tdnf/locks.d
echo kernel > /etc/tdnf/locks.d/kernel.conf # wild cards don't seem  to work
echo kernel-headers >> /etc/tdnf/locks.d/kernel.conf
echo kmod >> /etc/tdnf/locks.d/kernel.conf

# Disable dependencies on kernel core
#sed -i "$ s/$/ shim*/" /etc/dnf/dnf.conf
#sed -i "$ s/$/ grub2*/" /etc/dnf/dnf.conf

# Enable kernel log messages to file as per HPC requirement.
sed -i 's/^\#kern\.\*.*/kern\.\*                                \-\/var\/log\/kern.log/' /etc/rsyslog.conf
# Add kern.log from rsyslog to logrotate
sed -i 's#/var/log/maillog#/var/log/maillog\n/var/log/kern.log#' /etc/logrotate.d/rsyslog

# Disable dependencies on kernel core
#sed -i "$ s/$/ shim*/" /etc/dnf/dnf.conf
#sed -i "$ s/$/ grub2*/" /etc/dnf/dnf.conf

## Install dkms
tdnf install -y dkms

## Install subunit and subunit-devel
tdnf install -y subunit
tdnf install -y subunit-devel


## Install libmd and libmd-devel 
tdnf install -y libmd
tdnf install -y libmd-devel

# copy kvp client file
$COMMON_DIR/copy_kvp_client.sh

# copy torset tool
$COMMON_DIR/copy_torset_tool.sh

# Create alias for "ls -l"
echo "alias ll='ls -l'" | tee -a /etc/bash.bashrc

