#!/bin/bash
set -ex

# Install Cuda
NVIDIA_VERSION="495.29.05"
CUDA_VERSION="11.5.0"
$COMMON_DIR/write_component_version.sh "CUDA" ${CUDA_VERSION}
CUDA_URL=https://developer.download.nvidia.com/compute/cuda/${CUDA_VERSION}/local_installers/cuda_${CUDA_VERSION}_${NVIDIA_VERSION}_linux.run
$COMMON_DIR/download_and_verify.sh $CUDA_URL "ae0a1693d9497cf3d81e6948943e3794636900db71c98d58eefdacaf7f1a1e4c"
chmod +x cuda_${CUDA_VERSION}_${NVIDIA_VERSION}_linux.run
sh cuda_${CUDA_VERSION}_${NVIDIA_VERSION}_linux.run --silent
echo 'export PATH=$PATH:/usr/local/cuda/bin' | sudo tee -a /etc/bash.bashrc
echo 'export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/cuda/lib64' | sudo tee -a /etc/bash.bashrc

# Nvidia driver
NVIDIA_DRIVER_URL=https://download.nvidia.com/XFree86/Linux-x86_64/${NVIDIA_VERSION}/NVIDIA-Linux-x86_64-${NVIDIA_VERSION}.run
$COMMON_DIR/download_and_verify.sh $NVIDIA_DRIVER_URL "f7254b97d400c692504796496f4e7d8f64e93b1e31c427860a4f219a186f125e"
bash NVIDIA-Linux-x86_64-${NVIDIA_VERSION}.run --silent
$COMMON_DIR/write_component_version.sh "NVIDIA" ${NVIDIA_VERSION}
