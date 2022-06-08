#!/bin/bash

set -e

# Dependencies 
pip3 install --upgrade pip
python3 -m pip install ansible

MONITOR_DIR=/opt/azurehpc/monitoring

mkdir -p $MONITOR_DIR


pushd $MONITOR_DIR

git clone https://github.com/Azure/Moneo  --branch v0.1.1

popd
