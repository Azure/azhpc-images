#!/bin/bash
set -ex

VERSION="5.4-3.0.0.0"
$COMMON_DIR/write_component_version.sh "MOFED" $VERSION
TARBALL="MLNX_OFED_LINUX-$VERSION-ubuntu18.04-x86_64.tgz"
MLNX_OFED_DOWNLOAD_URL=https://azhpcstor.blob.core.windows.net/azhpc-images-store/$TARBALL
MOFED_FOLDER=$(basename ${MLNX_OFED_DOWNLOAD_URL} .tgz)

$COMMON_DIR/download_and_verify.sh $MLNX_OFED_DOWNLOAD_URL "547ffc00da06bc4e2a3c6bc4a49879b6b63b2a1b3d7c8013871f2937c1e17e55"
tar zxvf ${TARBALL}

./${MOFED_FOLDER}/mlnxofedinstall --add-kernel-support --skip-unsupported-devices-check --without-fw-update

# Restarting openibd
/etc/init.d/openibd restart
