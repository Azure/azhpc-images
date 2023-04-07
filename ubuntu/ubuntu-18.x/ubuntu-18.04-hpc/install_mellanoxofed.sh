#!/bin/bash
set -ex

VERSION="5.8-2.0.3.0"
TARBALL="MLNX_OFED_LINUX-$VERSION-ubuntu18.04-x86_64.tgz"
MLNX_OFED_DOWNLOAD_URL=https://content.mellanox.com/ofed/MLNX_OFED-${VERSION}/$TARBALL
MOFED_FOLDER=$(basename ${MLNX_OFED_DOWNLOAD_URL} .tgz)

$COMMON_DIR/download_and_verify.sh $MLNX_OFED_DOWNLOAD_URL "37b3f86e0172c80e79428ef09e5f45108044e428780273d7dc18b9f54f8d4a2d"
tar zxvf ${TARBALL}

./${MOFED_FOLDER}/mlnxofedinstall --add-kernel-support --skip-unsupported-devices-check --without-fw-update
$COMMON_DIR/write_component_version.sh "MOFED" $VERSION

# Restarting openibd
/etc/init.d/openibd restart

## Fix for systemd-modules-load service failing on boot
rm -rf /lib/modules/$(uname -r)/kernel/drivers/infiniband/ulp/iser/ib_iser.ko
depmod
