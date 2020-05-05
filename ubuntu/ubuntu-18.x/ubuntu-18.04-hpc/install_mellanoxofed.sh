#!/bin/bash
set -ex

# Change versions (Ubuntu, OFED) here if needed
# See https://github.com/Azure/azhpc-extensions/blob/master/InfiniBand/Linux/resources.json
DRIVER_URL=http://content.mellanox.com/ofed/MLNX_OFED-5.0-1.0.0.0/MLNX_OFED_LINUX-5.0-1.0.0.0-ubuntu18.04-x86_64.tgz

$COMMON_DIR/download_and_verify.sh $DRIVER_URL "3a198e1114d22fe31338003ef6b8c0e7b082ce719a764b5165727eac63d2b5db"
DRIVER_FILE=$(basename $DRIVER_URL) # Extract filename of tarball
tar xzf $DRIVER_FILE           # Extract tarball
DRIVER_ROOT=${DRIVER_FILE%.*}       # Extract root without .tgz

./$DRIVER_ROOT/mlnxofedinstall --add-kernel-support
