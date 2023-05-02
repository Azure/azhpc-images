#!/bin/bash
set -ex

VERSION="5.9-0.5.9.0"
TARBALL="MLNX_OFED_LINUX-$VERSION-ubuntu18.04-x86_64.tgz"
MLNX_OFED_DOWNLOAD_URL=https://content.mellanox.com/ofed/MLNX_OFED-${VERSION}/$TARBALL
MOFED_FOLDER=$(basename ${MLNX_OFED_DOWNLOAD_URL} .tgz)

$COMMON_DIR/download_and_verify.sh $MLNX_OFED_DOWNLOAD_URL "2d773d682c4899ca6b9e77ab93886abecf0afb1049cad93d15a1a5dc9cbf0c30"
tar zxvf ${TARBALL}

./${MOFED_FOLDER}/mlnxofedinstall --add-kernel-support --skip-unsupported-devices-check --without-fw-update
$COMMON_DIR/write_component_version.sh "MOFED" $VERSION

# Restarting openibd
/etc/init.d/openibd restart

## Fix for systemd-modules-load service failing on boot
rm -rf /lib/modules/$(uname -r)/kernel/drivers/infiniband/ulp/iser/ib_iser.ko
depmod
