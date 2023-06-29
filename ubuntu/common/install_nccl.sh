#!/bin/bash
set -ex

apt install -y zlib1g-dev
$COMMON_DIR/install_nccl.sh
