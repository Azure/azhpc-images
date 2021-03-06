#!/bin/bash
set -ex

$UBUNTU_COMMON_DIR/install_nvidiagpudriver.sh

# Install nvidia fabric manager (required for ND96asr_v4)
NVIDIA_FABRIC_MNGR_URL=http://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/nvidia-fabricmanager-460_460.32.03-1_amd64.deb
$COMMON_DIR/download_and_verify.sh $NVIDIA_FABRIC_MNGR_URL "157da63c4f7823bb5ae4428891978345a079830629e23579e0c3126f42a4411c"
apt install -y ./nvidia-fabricmanager-460_460.32.03-1_amd64.deb
apt-mark hold nvidia-fabricmanager-460
systemctl enable nvidia-fabricmanager
systemctl start nvidia-fabricmanager
