#!/bin/bash

set -e

# Dependencies 
python3 -m pip install --upgrade pip
python3 -m pip install ansible

MONITOR_DIR=/opt/azurehpc/tools

mkdir -p $MONITOR_DIR

pushd $MONITOR_DIR

git clone https://github.com/Azure/Moneo  --branch v0.2.3

chmod 777 Moneo

popd
