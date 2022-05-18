#!/bin/bash
set -ex

# Parameter
# Ubuntu Version
VERSION=$1

# Install nvidia fabric manager (required for ND96asr_v4)
NVIDIA_FABRIC_MANAGER_VERSION="510_510.47.03-1"
NVIDIA_FABRIC_MNGR_URL=http://developer.download.nvidia.com/compute/cuda/repos/ubuntu${VERSION}/x86_64/nvidia-fabricmanager-${NVIDIA_FABRIC_MANAGER_VERSION}_amd64.deb
$COMMON_DIR/download_and_verify.sh $NVIDIA_FABRIC_MNGR_URL "5636b87336c3ba0533c9ad7e85e7e5545e446056d08b1dbd63b7ca65c4f8f750"
apt install -y ./nvidia-fabricmanager-${NVIDIA_FABRIC_MANAGER_VERSION}_amd64.deb
sudo apt-mark hold nvidia-fabricmanager-510
$COMMON_DIR/write_component_version.sh "NVIDIA_FABRIC_MANAGER" ${NVIDIA_FABRIC_MANAGER_VERSION}
systemctl enable nvidia-fabricmanager
systemctl start nvidia-fabricmanager
