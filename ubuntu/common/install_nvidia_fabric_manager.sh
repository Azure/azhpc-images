#!/bin/bash
set -ex

# Parameter
# Ubuntu Version
VERSION=$1

# Install nvidia fabric manager
NVIDIA_FABRIC_MANAGER_VERSION="525_525.85.12-1"
NVIDIA_FABRIC_MNGR_URL=http://developer.download.nvidia.com/compute/cuda/repos/ubuntu${VERSION}/x86_64/nvidia-fabricmanager-${NVIDIA_FABRIC_MANAGER_VERSION}_amd64.deb
$COMMON_DIR/download_and_verify.sh $NVIDIA_FABRIC_MNGR_URL "77e2f8768e4901114c35582b530b10fe6bd3b924862a929f96fc83aee078b12c"
apt install -y ./nvidia-fabricmanager-${NVIDIA_FABRIC_MANAGER_VERSION}_amd64.deb
sudo apt-mark hold nvidia-fabricmanager-525
$COMMON_DIR/write_component_version.sh "NVIDIA_FABRIC_MANAGER" ${NVIDIA_FABRIC_MANAGER_VERSION}
