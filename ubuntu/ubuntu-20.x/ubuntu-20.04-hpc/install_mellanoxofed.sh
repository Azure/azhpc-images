#!/bin/bash
set -ex

mofed_metadata=$(jq -r '.mofed."'"$DISTRIBUTION"'"' <<< $COMPONENT_VERSIONS)
MOFED_VERSION=$(jq -r '.version' <<< $mofed_metadata)
MOFED_SHA256=$(jq -r '.sha256' <<< $mofed_metadata)
TARBALL="MLNX_OFED_LINUX-$MOFED_VERSION-ubuntu20.04-x86_64.tgz"
MLNX_OFED_DOWNLOAD_URL=https://content.mellanox.com/ofed/MLNX_OFED-${MOFED_VERSION}/$TARBALL
MOFED_FOLDER=$(basename ${MLNX_OFED_DOWNLOAD_URL} .tgz)

$COMMON_DIR/download_and_verify.sh $MLNX_OFED_DOWNLOAD_URL $MOFED_SHA256
tar zxvf ${TARBALL}

./${MOFED_FOLDER}/mlnxofedinstall --add-kernel-support --skip-unsupported-devices-check --without-fw-update
$COMMON_DIR/write_component_version.sh "MOFED" $MOFED_VERSION

# Restarting openibd
/etc/init.d/openibd restart
