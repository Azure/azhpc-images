#!/bin/bash
set -ex

MLNX_OFED_DOWNLOAD_URL=http://content.mellanox.com/ofed/MLNX_OFED-5.1-2.3.7.1/MLNX_OFED_LINUX-5.1-2.3.7.1-rhel7.8-x86_64.tgz
TARBALL=$(basename ${MLNX_OFED_DOWNLOAD_URL})
MOFED_FOLDER=$(basename ${MLNX_OFED_DOWNLOAD_URL} .tgz)

$COMMON_DIR/download_and_verify.sh $MLNX_OFED_DOWNLOAD_URL "9d3b8ed5c16f91622552960ea5b28e56aaed6a523174edf4979001c7dc307ac9"
tar zxvf ${TARBALL}

KERNEL=( $(rpm -q kernel | sed 's/kernel\-//g') )
KERNEL=${KERNEL[-1]}
# Uncomment the lines below if you are running this on a VM
#RELEASE=( $(cat /etc/centos-release | awk '{print $4}') )
#yum -y install http://olcentgbl.trafficmanager.net/centos/${RELEASE}/updates/x86_64/kernel-devel-${KERNEL}.rpm
yum install -y kernel-devel-${KERNEL}
./${MOFED_FOLDER}/mlnxofedinstall --kernel $KERNEL --kernel-sources /usr/src/kernels/${KERNEL} --add-kernel-support --skip-repo

