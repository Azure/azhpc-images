#!/bin/bash
set -ex

VERSION="4.9-6.0.6.0"
TARBALL="MLNX_OFED_LINUX-$VERSION-ubuntu20.04-x86_64.tgz"
MLNX_OFED_DOWNLOAD_URL=https://content.mellanox.com/ofed/MLNX_OFED-${VERSION}/$TARBALL
MOFED_FOLDER=$(basename ${MLNX_OFED_DOWNLOAD_URL} .tgz)

$COMMON_DIR/download_and_verify.sh $MLNX_OFED_DOWNLOAD_URL "5cafde8a345a1694f4fc93ba78c6206f30ead005807bf3ba8a4f5c4f388616a9"
tar zxvf ${TARBALL}

./${MOFED_FOLDER}/mlnxofedinstall --add-kernel-support --without-fw-update
$COMMON_DIR/write_component_version.sh "MOFED" $VERSION

# Restarting openibd
/etc/init.d/openibd restart
