#!/bin/bash

# Install kernel libs, these should already be installed with Mellanox OFED installation
KERNEL=( $(rpm -q kernel | sed 's/kernel\-//g') )
KERNEL=${KERNEL[-1]}
# Uncomment the lines below if you are running this on a VM
#RELEASE=( $(cat /etc/centos-release | awk '{print $4}') )
#yum install -y http://olcentwus.cloudapp.net/centos/${RELEASE}/BaseOS/x86_64/os/kernel-devel-${KERNEL}.rpm
#yum install -y http://olcentwus.cloudapp.net/centos/${RELEASE}/BaseOS/x86_64/os/kernel-headers-${KERNEL}.rpm
yum install -y kernel-devel-${KERNEL}
yum install -y kernel-headers-${KERNEL}

# Install DKMS
sudo dnf install -y dkms

$COMMON_DIR/install_nvidiagpudriver.sh