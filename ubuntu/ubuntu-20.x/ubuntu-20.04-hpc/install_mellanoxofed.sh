#!/bin/bash
set -ex

MLNX_OFED_DOWNLOAD_URL=https://azhpcstor.blob.core.windows.net/azhpc-images-store/MLNX_OFED_LINUX-5.2-2.2.3.0-ubuntu20.04-x86_64.tgz
TARBALL=$(basename ${MLNX_OFED_DOWNLOAD_URL})
MOFED_FOLDER=$(basename ${MLNX_OFED_DOWNLOAD_URL} .tgz)

$COMMON_DIR/download_and_verify.sh $MLNX_OFED_DOWNLOAD_URL "72d38888489ba15784d5500fef9ff09c9ef338a5cdd44bfd916a63b06af28ef0"
tar zxvf ${TARBALL}

./${MOFED_FOLDER}/mlnxofedinstall --add-kernel-support --skip-unsupported-devices-check

