#!/bin/bash

set -e

# Dependencies 
pip3 install --upgrade pip
python3 -m pip install ansible

MONITOR_DIR=/opt/azurehpc/tools

mkdir -p $MONITOR_DIR

#need to remove cuda signed list
rm /etc/apt/sources.list.d/cuda-ubuntu*.list 2> /dev/null

pushd $MONITOR_DIR

git clone https://github.com/Azure/Moneo  --branch v0.2.0

popd
