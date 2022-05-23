#!/bin/bash
set -ex

# Install Cuda
NVIDIA_VERSION="510.47.03"
CUDA_VERSION="11.6.1"
CUDA_URL=https://developer.download.nvidia.com/compute/cuda/${CUDA_VERSION}/local_installers/cuda_${CUDA_VERSION}_${NVIDIA_VERSION}_linux.run
$COMMON_DIR/download_and_verify.sh $CUDA_URL "ab219afce00b74200113269866fbff75ead037bcfc23551a8338c2684c984d7e"
chmod +x cuda_${CUDA_VERSION}_${NVIDIA_VERSION}_linux.run
sh cuda_${CUDA_VERSION}_${NVIDIA_VERSION}_linux.run --silent
echo 'export PATH=$PATH:/usr/local/cuda/bin' | tee -a /etc/bash.bashrc
echo 'export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/cuda/lib64' | tee -a /etc/bash.bashrc
$COMMON_DIR/write_component_version.sh "CUDA" ${CUDA_VERSION}

# Download CUDA samples
CUDA_SAMPLES_VERSION="11.6"
TARBALL="v${CUDA_SAMPLES_VERSION}.tar.gz"
CUDA_SAMPLES_DOWNLOAD_URL=https://github.com/NVIDIA/cuda-samples/archive/refs/tags/${TARBALL}
wget ${CUDA_SAMPLES_DOWNLOAD_URL}
tar -xvf ${TARBALL}
pushd ./cuda-samples-${CUDA_SAMPLES_VERSION}
make
cp -r ./Samples/* /usr/local/cuda-11.6/samples/
popd

# Nvidia driver
NVIDIA_DRIVER_URL=https://download.nvidia.com/XFree86/Linux-x86_64/${NVIDIA_VERSION}/NVIDIA-Linux-x86_64-${NVIDIA_VERSION}.run
$COMMON_DIR/download_and_verify.sh $NVIDIA_DRIVER_URL "f2a421dae836318d3c0d96459ccb3af27e90e50c95b0faa4288af76279e5d690"
bash NVIDIA-Linux-x86_64-${NVIDIA_VERSION}.run --silent --dkms
$COMMON_DIR/write_component_version.sh "NVIDIA" ${NVIDIA_VERSION}
