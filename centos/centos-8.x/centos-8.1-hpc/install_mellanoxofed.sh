#!/bin/bash
set -ex

VERSION="5.4-1.0.3.0"
$COMMON_DIR/write_component_version.sh "MOFED" $VERSION
TARBALL="MLNX_OFED_LINUX-$VERSION-rhel8.1-x86_64.tgz"
MLNX_OFED_DOWNLOAD_URL=https://azhpcstor.blob.core.windows.net/azhpc-images-store/$TARBALL
MOFED_FOLDER=$(basename ${MLNX_OFED_DOWNLOAD_URL} .tgz)

$COMMON_DIR/download_and_verify.sh $MLNX_OFED_DOWNLOAD_URL "171b304d76f2e88ec62138b01691a5580c5fa3674209f262592669c637891c13"
tar zxvf ${TARBALL}

# Uncomment the lines below if you are running this on a VM
#KERNEL=( $(rpm -q kernel | sed 's/kernel\-//g') )
#KERNEL=${KERNEL[-1]}
#RELEASE=( $(cat /etc/centos-release | awk '{print $4}') )
#yum install -y https://packages.microsoft.com/yumrepos/1.0-eval-base-x8664-rpms/Packages/k/kernel-devel-${KERNEL}.rpm
#yum install -y https://packages.microsoft.com/yumrepos/1.0-eval-base-x8664-rpms/Packages/k/kernel-modules-extra-${KERNEL}.rpm

yum install -y kernel-devel
yum install -y kernel-modules-extra
KERNEL=( $(rpm -q kernel-devel | sed 's/kernel-devel\-//g') )
KERNEL=${KERNEL[-1]}

./${MOFED_FOLDER}/mlnxofedinstall --kernel $KERNEL --kernel-sources /usr/src/kernels/${KERNEL} --add-kernel-support --skip-repo --skip-unsupported-devices-check --without-fw-update

# Issue: Module mlx5_ib belong to a kernel which is not a part of MLNX
# Resolution: set FORCE=1/ force-restart /etc/init.d/openibd 
# This causes openibd to ignore the kernel difference but relies on weak-updates
# Restarting openibd
/etc/init.d/openibd force-restart
