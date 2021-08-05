#!/bin/bash
set -ex

VERSION="5.4-1.0.3.0"
$COMMON_DIR/write_component_version.sh "MOFED" $VERSION
TARBALL="MLNX_OFED_LINUX-$VERSION-ubuntu18.04-x86_64.tgz"
MLNX_OFED_DOWNLOAD_URL=https://azhpcstor.blob.core.windows.net/azhpc-images-store/$TARBALL
MOFED_FOLDER=$(basename ${MLNX_OFED_DOWNLOAD_URL} .tgz)

$COMMON_DIR/download_and_verify.sh $MLNX_OFED_DOWNLOAD_URL "6883710af0929e75d3254b2ffaea6fc1148e6997e28833eef751f4851cf42d30"
tar zxvf ${TARBALL}

./${MOFED_FOLDER}/mlnxofedinstall --add-kernel-support --skip-unsupported-devices-check

# Restarting openibd
/etc/init.d/openibd restart
