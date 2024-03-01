#!/bin/bash
set -ex

# Set the GCC version
export GCC_VERSION=$(gcc --version | grep gcc | awk '{print $4}')

$COMMON_DIR/install_amd_libs.sh
