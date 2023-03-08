#!/bin/bash
set -ex

VERSION="5.9-0.5.6.0"
TARBALL="MLNX_OFED_LINUX-$VERSION-ubuntu18.04-x86_64.tgz"
MLNX_OFED_DOWNLOAD_URL=https://content.mellanox.com/ofed/MLNX_OFED-${VERSION}/$TARBALL
MOFED_FOLDER=$(basename ${MLNX_OFED_DOWNLOAD_URL} .tgz)

$COMMON_DIR/download_and_verify.sh $MLNX_OFED_DOWNLOAD_URL "c50a3fb7263a2e063d1fbe22f4e81e456807067430e46d0b05086a06b948c236"
tar zxvf ${TARBALL}

./${MOFED_FOLDER}/mlnxofedinstall --add-kernel-support --skip-unsupported-devices-check --without-fw-update
$COMMON_DIR/write_component_version.sh "MOFED" $VERSION

# Restarting openibd
/etc/init.d/openibd restart

## Fix for systemd-modules-load service failing on boot
rm -rf /lib/modules/$(uname -r)/kernel/drivers/infiniband/ulp/iser/ib_iser.ko
depmod
