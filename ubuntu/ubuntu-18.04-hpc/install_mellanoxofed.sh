#!/bin/bash
set -ex

# Change versions (Ubuntu, OFED) here if needed
# See https://github.com/Azure/azhpc-extensions/blob/master/InfiniBand/Linux/resources.json
DRIVER_URL=http://content.mellanox.com/ofed/MLNX_OFED-5.0-1.0.0.0/MLNX_OFED_LINUX-5.0-1.0.0.0-ubuntu18.04-x86_64.tgz

sudo wget --retry-connrefused --tries=3 --waitretry=5 $DRIVER_URL -nv # Download tarball
DRIVER_FILE=$(basename $DRIVER_URL) # Extract filename of tarball
sudo tar xzf $DRIVER_FILE           # Extract tarball
DRIVER_ROOT=${DRIVER_FILE%.*}       # Extract root without .tgz

./$DRIVER_ROOT/mlnxofedinstall --add-kernel-support
