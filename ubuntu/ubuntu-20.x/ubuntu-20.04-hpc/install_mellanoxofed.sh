#!/bin/bash
set -ex

VERSION="5.4-3.0.0.0"
$COMMON_DIR/write_component_version.sh "MOFED" $VERSION
TARBALL="MLNX_OFED_LINUX-$VERSION-ubuntu20.04-x86_64.tgz"
MLNX_OFED_DOWNLOAD_URL=https://azhpcstor.blob.core.windows.net/azhpc-images-store/$TARBALL
MOFED_FOLDER=$(basename ${MLNX_OFED_DOWNLOAD_URL} .tgz)

$COMMON_DIR/download_and_verify.sh $MLNX_OFED_DOWNLOAD_URL "4a553572286f37cf649d68d70ffecd3d9acf5ba61a0935bb44d7b194782fdd39"
tar zxvf ${TARBALL}

./${MOFED_FOLDER}/mlnxofedinstall --add-kernel-support --skip-unsupported-devices-check

# Restarting openibd
/etc/init.d/openibd restart
