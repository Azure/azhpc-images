#!/bin/bash
set -ex

MLNX_OFED_DOWNLOAD_URL=http://content.mellanox.com/ofed/MLNX_OFED-5.0-2.1.8.0/MLNX_OFED_LINUX-5.0-2.1.8.0-rhel8.1-x86_64.tgz
$COMMON_DIR/download_and_verify.sh $MLNX_OFED_DOWNLOAD_URL "587f0075f36c76b8e7e2f8c5794d92ae9e1000ffc7450847c7856c2b098c8cfb"
tar zxvf MLNX_OFED_LINUX-5.0-2.1.8.0-rhel8.1-x86_64.tgz

KERNEL=( $(rpm -q kernel | sed 's/kernel\-//g') )
KERNEL=${KERNEL[-1]}
# Uncomment the lines below if you are running this on a VM
#RELEASE=( $(cat /etc/centos-release | awk '{print $4}') )
#yum install -y http://olcentwus.cloudapp.net/centos/${RELEASE}/BaseOS/x86_64/os/kernel-devel-${KERNEL}.rpm
yum install -y kernel-devel-${KERNEL}
./MLNX_OFED_LINUX-5.0-2.1.8.0-rhel8.1-x86_64/mlnxofedinstall --kernel $KERNEL --kernel-sources /usr/src/kernels/${KERNEL} --add-kernel-support --skip-repo
