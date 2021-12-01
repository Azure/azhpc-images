#!/bin/bash
set -ex

# Install Cuda
NVIDIA_VERSION="470.82.01"
CUDA_VERSION="11.4.3"
$COMMON_DIR/write_component_version.sh "CUDA" ${CUDA_VERSION}
CUDA_URL=https://developer.download.nvidia.com/compute/cuda/${CUDA_VERSION}/local_installers/cuda_${CUDA_VERSION}_${NVIDIA_VERSION}_linux.run
$COMMON_DIR/download_and_verify.sh $CUDA_URL "749183821ffc051e123f12ebdeb171b263d55b86f0dd7c8f23611db1802d6c37"
chmod +x cuda_${CUDA_VERSION}_${NVIDIA_VERSION}_linux.run
sh cuda_${CUDA_VERSION}_${NVIDIA_VERSION}_linux.run --silent
echo 'export PATH=$PATH:/usr/local/cuda/bin' | sudo tee -a /etc/bash.bashrc
echo 'export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/cuda/lib64' | sudo tee -a /etc/bash.bashrc

# Nvidia driver
NVIDIA_DRIVER_URL=https://download.nvidia.com/XFree86/Linux-x86_64/${NVIDIA_VERSION}/NVIDIA-Linux-x86_64-${NVIDIA_VERSION}.run
$COMMON_DIR/download_and_verify.sh $NVIDIA_DRIVER_URL "ad78fc2b29b8f498015277e30ae42530b61fecc298706bc0e9c193ee5e9c0660"
bash NVIDIA-Linux-x86_64-${NVIDIA_VERSION}.run --silent --dkms
$COMMON_DIR/write_component_version.sh "NVIDIA" ${NVIDIA_VERSION}
