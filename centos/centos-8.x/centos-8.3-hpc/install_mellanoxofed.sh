#!/bin/bash
set -ex

VERSION="5.8-1.0.1.1"
TARBALL="MLNX_OFED_LINUX-$VERSION-rhel8.3-x86_64.tgz"
MLNX_OFED_DOWNLOAD_URL=https://content.mellanox.com/ofed/MLNX_OFED-${VERSION}/$TARBALL
MOFED_FOLDER=$(basename ${MLNX_OFED_DOWNLOAD_URL} .tgz)

$COMMON_DIR/download_and_verify.sh $MLNX_OFED_DOWNLOAD_URL "370f49fd9190f046e1a41853e9f03508b57f1a29fa01f73099e564e6529a979d"
tar zxvf ${TARBALL}

KERNEL=( $(rpm -q kernel | sed 's/kernel\-//g') )
# Uncomment the lines below if you are running this on a VM
# RELEASE=( $(cat /etc/centos-release | awk '{print $4}') )
# yum install -y https://vault.centos.org/${RELEASE}/BaseOS/x86_64/os/Packages/kernel-devel-${KERNEL}.rpm
# yum install -y https://vault.centos.org/${RELEASE}/BaseOS/x86_64/os/Packages/kernel-modules-extra-${KERNEL}.rpm
yum install -y kernel-devel-${KERNEL} kernel-modules-extra-${KERNEL}
./${MOFED_FOLDER}/mlnxofedinstall --kernel $KERNEL --kernel-sources /usr/src/kernels/${KERNEL} --add-kernel-support --skip-repo --skip-unsupported-devices-check --without-fw-update

# Issue: Module mlx5_ib belong to a kernel which is not a part of MLNX
# Resolution: set FORCE=1/ force-restart /etc/init.d/openibd 
# This causes openibd to ignore the kernel difference but relies on weak-updates
# Restarting openibd
/etc/init.d/openibd force-restart
systemctl restart openibd
systemctl is-active --quiet openibd

error_code=$?
if [ ${error_code} -ne 0 ]
then
    echo "openibd service inactive/dead!"
    exit ${error_code}
fi

# Disable kernel updates
echo "exclude=kernel* kmod*" | tee -a /etc/dnf/dnf.conf
# exclude opensm from updates
sed -i "$ s/$/ opensm*/" /etc/dnf/dnf.conf
$COMMON_DIR/write_component_version.sh "MOFED" $VERSION
