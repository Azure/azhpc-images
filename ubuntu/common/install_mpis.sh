#!/bin/bash
set -ex

# Load gcc
set CC=/usr/bin/gcc
set GCC=/usr/bin/gcc
GCC_VERSION=$(gcc --version | grep gcc | awk '{print $4}')

$COMMON_DIR/install_mpis.sh
