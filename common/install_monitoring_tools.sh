#!/bin/bash

set -e

MONITOR_DIR=/opt/azurehpc/monitoring

mkdir -p $MONITOR_DIR


pushd $MONITOR_DIR

git clone https://github.com/Azure/Moneo  --branch v0.1.0

popd
