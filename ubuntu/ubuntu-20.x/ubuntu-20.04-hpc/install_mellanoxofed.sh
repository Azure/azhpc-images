#!/bin/bash
set -ex

VERSION="5.6-1.0.3.3"
TARBALL="MLNX_OFED_LINUX-$VERSION-ubuntu20.04-x86_64.tgz"
MLNX_OFED_DOWNLOAD_URL=https://azhpcstor.blob.core.windows.net/azhpc-images-store/$TARBALL
MOFED_FOLDER=$(basename ${MLNX_OFED_DOWNLOAD_URL} .tgz)

$COMMON_DIR/download_and_verify.sh $MLNX_OFED_DOWNLOAD_URL "047c0aa106718e88062c7e65c14435291f534428f150f3173000ec07c40d943e"
tar zxvf ${TARBALL}

./${MOFED_FOLDER}/mlnxofedinstall --add-kernel-support --skip-unsupported-devices-check --without-fw-update
$COMMON_DIR/write_component_version.sh "MOFED" $VERSION

# Restarting openibd
/etc/init.d/openibd restart
