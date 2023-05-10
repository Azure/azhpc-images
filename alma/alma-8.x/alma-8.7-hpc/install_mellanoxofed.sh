#!/bin/bash
set -ex

VERSION="23.04-0.5.3.3"
TARBALL="MLNX_OFED_LINUX-$VERSION-rhel8.7-x86_64.tgz"
MLNX_OFED_DOWNLOAD_URL=https://content.mellanox.com/ofed/MLNX_OFED-${VERSION}/$TARBALL
MOFED_FOLDER=$(basename ${MLNX_OFED_DOWNLOAD_URL} .tgz)

$COMMON_DIR/download_and_verify.sh $MLNX_OFED_DOWNLOAD_URL "1b9edbce2c30e62a5bcb5de087411532048b0987fadc62297af3cf9c2c45f444"
tar zxvf ${TARBALL}

KERNEL=( $(rpm -q kernel | sed 's/kernel\-//g') )
KERNEL=${KERNEL[-1]}
./${MOFED_FOLDER}/mlnxofedinstall --kernel $KERNEL --kernel-sources /usr/src/kernels/${KERNEL} --add-kernel-support --skip-repo --skip-unsupported-devices-check --without-fw-update --distro rhel8.7

# Issue: Module mlx5_ib belong to a kernel which is not a part of MLNX
# Resolution: set FORCE=1/ force-restart /etc/init.d/openibd 
# This causes openibd to ignore the kernel difference but relies on weak-updates
# Restarting openibd
/etc/init.d/openibd force-restart
$COMMON_DIR/write_component_version.sh "MOFED" $VERSION

# exclude opensm from updates
sed -i "$ s/$/ opensm*/" /etc/dnf/dnf.conf

# cleanup downloaded files
rm -rf *.tgz
rm -rf -- */
