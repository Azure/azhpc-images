#!/bin/bash
set -ex

VERSION="5.4-1.0.3.0"
$COMMON_DIR/write_component_version.sh "MOFED" ${VERSION}
TARBALL="MLNX_OFED_LINUX-${VERSION}-rhel7.7-x86_64.tgz"
MLNX_OFED_DOWNLOAD_URL=https://azhpcstor.blob.core.windows.net/azhpc-images-store/$TARBALL
MOFED_FOLDER=$(basename ${MLNX_OFED_DOWNLOAD_URL} .tgz)

$COMMON_DIR/download_and_verify.sh $MLNX_OFED_DOWNLOAD_URL "e12e7d1606c8ad875c61be261d45e7cd11b0e15258ca29f7a6830077c57c9792"
tar zxvf ${TARBALL}

KERNEL=( $(rpm -q kernel | sed 's/kernel\-//g') )
KERNEL=${KERNEL[-1]}
# Uncomment the lines below if you are running this on a VM
#RELEASE=( $(cat /etc/centos-release | awk '{print $4}') )
#yum -y install http://olcentgbl.trafficmanager.net/centos/${RELEASE}/updates/x86_64/kernel-devel-${KERNEL}.rpm
yum install -y kernel-devel-${KERNEL}
./${MOFED_FOLDER}/mlnxofedinstall --kernel $KERNEL --kernel-sources /usr/src/kernels/${KERNEL} --add-kernel-support --skip-repo

# Restarting openibd
/etc/init.d/openibd restart
