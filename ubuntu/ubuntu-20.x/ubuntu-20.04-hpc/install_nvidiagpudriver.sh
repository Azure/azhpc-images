#!/bin/bash

$COMMON_DIR/install_nvidiagpudriver.sh

# Install nvidia fabric manager (required for ND96asr_v4)
NVIDIA_FABRIC_MNGR_URL=http://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/nvidia-fabricmanager-450_450.80.02-1_amd64.deb
$COMMON_DIR/download_and_verify.sh $NVIDIA_FABRIC_MNGR_URL "4f14f162ad40e0824695f7489e27b24cf762b733ffcb0f30f084a228659594bf"
sudo apt install -y ./nvidia-fabricmanager-450_450.80.02-1_amd64.deb
sudo systemctl enable nvidia-fabricmanager
sudo systemctl start nvidia-fabricmanager
