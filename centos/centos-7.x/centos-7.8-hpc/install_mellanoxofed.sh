#!/bin/bash
set -ex

MLNX_OFED_DOWNLOAD_URL=https://azhpcstor.blob.core.windows.net/azhpc-images-store/MLNX_OFED_LINUX-5.2-2.2.3.0-rhel7.8-x86_64.tgz
TARBALL=$(basename ${MLNX_OFED_DOWNLOAD_URL})
MOFED_FOLDER=$(basename ${MLNX_OFED_DOWNLOAD_URL} .tgz)

$COMMON_DIR/download_and_verify.sh $MLNX_OFED_DOWNLOAD_URL "a8fa1f24462ab31ef514287ae74b4d7f63ddca5c4937700059e26e4eab7d04e5"
tar zxvf ${TARBALL}

KERNEL=( $(rpm -q kernel | sed 's/kernel\-//g') )
KERNEL=${KERNEL[-1]}
# Uncomment the lines below if you are running this on a VM
#RELEASE=( $(cat /etc/centos-release | awk '{print $4}') )
#yum -y install http://olcentgbl.trafficmanager.net/centos/${RELEASE}/updates/x86_64/kernel-devel-${KERNEL}.rpm
yum install -y kernel-devel-${KERNEL}
./${MOFED_FOLDER}/mlnxofedinstall --kernel $KERNEL --kernel-sources /usr/src/kernels/${KERNEL} --add-kernel-support --skip-repo

