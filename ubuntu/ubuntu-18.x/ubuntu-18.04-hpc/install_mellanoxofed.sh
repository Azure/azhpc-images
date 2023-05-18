#!/bin/bash
set -ex

VERSION="23.04-0.5.3.3"
TARBALL="MLNX_OFED_LINUX-$VERSION-ubuntu18.04-x86_64.tgz"
MLNX_OFED_DOWNLOAD_URL=https://content.mellanox.com/ofed/MLNX_OFED-${VERSION}/$TARBALL
MOFED_FOLDER=$(basename ${MLNX_OFED_DOWNLOAD_URL} .tgz)

$COMMON_DIR/download_and_verify.sh $MLNX_OFED_DOWNLOAD_URL "f7cbd64171650019eae27191895719ed0c0dc79164736db844f867a5a0fa4e02"
tar zxvf ${TARBALL}

./${MOFED_FOLDER}/mlnxofedinstall --add-kernel-support --skip-unsupported-devices-check --without-fw-update
$COMMON_DIR/write_component_version.sh "MOFED" $VERSION

# Restarting openibd
/etc/init.d/openibd restart

## Fix for systemd-modules-load service failing on boot
rm -rf /lib/modules/$(uname -r)/kernel/drivers/infiniband/ulp/iser/ib_iser.ko
depmod
