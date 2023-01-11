#!/bin/bash
set -ex

VERSION="5.8-1.0.1.1"
TARBALL="MLNX_OFED_LINUX-$VERSION-ubuntu18.04-x86_64.tgz"
MLNX_OFED_DOWNLOAD_URL=https://content.mellanox.com/ofed/MLNX_OFED-${VERSION}/$TARBALL
MOFED_FOLDER=$(basename ${MLNX_OFED_DOWNLOAD_URL} .tgz)

$COMMON_DIR/download_and_verify.sh $MLNX_OFED_DOWNLOAD_URL "6f9da70efa8af3b95df99cb0a6dcfba91a3ddddaf3b8f2a57522e1c7105aac30"
tar zxvf ${TARBALL}

./${MOFED_FOLDER}/mlnxofedinstall --add-kernel-support --skip-unsupported-devices-check --without-fw-update
$COMMON_DIR/write_component_version.sh "MOFED" $VERSION

# Restarting openibd
/etc/init.d/openibd restart

## Fix for systemd-modules-load service failing on boot
rm -rf /lib/modules/$(uname -r)/kernel/drivers/infiniband/ulp/iser/ib_iser.ko
depmod
