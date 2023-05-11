#!/bin/bash
set -ex

VERSION="23.04-0.5.3.3"
TARBALL="MLNX_OFED_LINUX-$VERSION-ubuntu20.04-x86_64.tgz"
MLNX_OFED_DOWNLOAD_URL=https://content.mellanox.com/ofed/MLNX_OFED-${VERSION}/$TARBALL
MOFED_FOLDER=$(basename ${MLNX_OFED_DOWNLOAD_URL} .tgz)

$COMMON_DIR/download_and_verify.sh $MLNX_OFED_DOWNLOAD_URL "dac77f7f65bf04053ee7fd5a4db58c913df9321a9ba9001928ce1681434538e1"
tar zxvf ${TARBALL}

./${MOFED_FOLDER}/mlnxofedinstall --add-kernel-support --skip-unsupported-devices-check --without-fw-update
$COMMON_DIR/write_component_version.sh "MOFED" $VERSION

# Restarting openibd
/etc/init.d/openibd restart
