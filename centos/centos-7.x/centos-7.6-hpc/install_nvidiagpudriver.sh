#!/bin/bash

# Install kernel libs, these should already be installed with Mellanox OFED installation
KERNEL=( $(rpm -q kernel | sed 's/kernel\-//g') )
KERNEL=${KERNEL[-1]}
# Uncomment the lines below if you are running this on a VM
#RELEASE=( $(cat /etc/centos-release | awk '{print $4}') )
#yum -y install http://olcentgbl.trafficmanager.net/centos/${RELEASE}/updates/x86_64/kernel-devel-${KERNEL}.rpm
#yum -y install http://olcentgbl.trafficmanager.net/centos/${RELEASE}/updates/x86_64/kernel-headers-${KERNEL}.rpm
yum install -y kernel-devel-${KERNEL}
yum install -y kernel-headers-${KERNEL}

$COMMON_DIR/install_nvidiagpudriver.sh