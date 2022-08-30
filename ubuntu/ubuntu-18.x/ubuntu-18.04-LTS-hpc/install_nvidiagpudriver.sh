#!/bin/bash
set -ex

# Parameters
RELEASE_VERSION=1804
CHECKSUM="749183821ffc051e123f12ebdeb171b263d55b86f0dd7c8f23611db1802d6c37"

# Reference - https://docs.nvidia.com/cuda/cuda-installation-guide-linux/index.html#ubuntu-installation
# Install Cuda
NVIDIA_VERSION="470.141.03"
CUDA_VERSION="11.4.3"
$COMMON_DIR/write_component_version.sh "CUDA" ${CUDA_VERSION}
CUDA_URL=https://developer.download.nvidia.com/compute/cuda/${CUDA_VERSION}/local_installers/cuda_${CUDA_VERSION}_${NVIDIA_VERSION}_linux.run
$COMMON_DIR/download_and_verify.sh $CUDA_URL "749183821ffc051e123f12ebdeb171b263d55b86f0dd7c8f23611db1802d6c37"
chmod +x cuda_${CUDA_VERSION}_${NVIDIA_VERSION}_linux.run
sh cuda_${CUDA_VERSION}_${NVIDIA_VERSION}_linux.run --silent
echo 'export PATH=$PATH:/usr/local/cuda/bin' | sudo tee -a /etc/bash.bashrc
echo 'export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/cuda/lib64' | sudo tee -a /etc/bash.bashrc

# Download CUDA samples
CUDA_SAMPLES_VERSION="11.4"
TARBALL="v${CUDA_SAMPLES_VERSION}.tar.gz"
CUDA_SAMPLES_DOWNLOAD_URL=https://github.com/NVIDIA/cuda-samples/archive/refs/tags/${TARBALL}
wget ${CUDA_SAMPLES_DOWNLOAD_URL}
tar -xvf ${TARBALL}
pushd ./cuda-samples-${CUDA_SAMPLES_VERSION}
make
cp -r ./Samples/* /usr/local/cuda-11.4/samples/
popd

# Nvidia driver
NVIDIA_DRIVER_URL=https://download.nvidia.com/XFree86/Linux-x86_64/${NVIDIA_VERSION}/NVIDIA-Linux-x86_64-${NVIDIA_VERSION}.run
$COMMON_DIR/download_and_verify.sh $NVIDIA_DRIVER_URL "be98d247a43d7491a65bfdc997fb6531e1594346eb12a0faaa044672cdb5709f"
bash NVIDIA-Linux-x86_64-${NVIDIA_VERSION}.run --silent --dkms
$COMMON_DIR/write_component_version.sh "NVIDIA" ${NVIDIA_VERSION}
