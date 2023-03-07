#!/bin/bash
set -ex

# Parameters
VERSION=$1

case ${VERSION} in
    1804) NVIDIA_VERSION="520.61.05"; 
        CUDA_VERSION="11.8"; 
        CUDA_SAMPLES_VERSION="11.8";
        CHECKSUM="10f6166703aeaffea237fa2d0ccacd0e9357af59b3bbc708a9097c9578509735";; 
    2004) NVIDIA_VERSION="525.85.12"; 
        CUDA_VERSION="12-0"; 
        CUDA_SAMPLES_VERSION="12.0";
        CHECKSUM="423b1d078e6385182f48c6e201e834b2eea193a622e04d613aa2259fce6e2266";;
    2204) NVIDIA_VERSION="525.85.12"; 
        CUDA_VERSION="12-0"; 
        CUDA_SAMPLES_VERSION="12.0";
        CHECKSUM="423b1d078e6385182f48c6e201e834b2eea193a622e04d613aa2259fce6e2266";;
    *) ;;
esac

# Reference - https://docs.nvidia.com/cuda/cuda-installation-guide-linux/index.html#ubuntu-installation
# Install Cuda
wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu${VERSION}/x86_64/cuda-keyring_1.0-1_all.deb
dpkg -i ./cuda-keyring_1.0-1_all.deb

apt-get update
apt install -y cuda-toolkit-${CUDA_VERSION}
echo 'export PATH=$PATH:/usr/local/cuda/bin' | tee -a /etc/bash.bashrc
echo 'export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/cuda/lib64' | tee -a /etc/bash.bashrc
$COMMON_DIR/write_component_version.sh "CUDA" ${CUDA_VERSION}

# Download CUDA samples
TARBALL="v${CUDA_SAMPLES_VERSION}.tar.gz"
CUDA_SAMPLES_DOWNLOAD_URL=https://github.com/NVIDIA/cuda-samples/archive/refs/tags/${TARBALL}
wget ${CUDA_SAMPLES_DOWNLOAD_URL}
tar -xvf ${TARBALL}
pushd ./cuda-samples-${CUDA_SAMPLES_VERSION}
make
mv ./Samples/ /usr/local/cuda-${CUDA_SAMPLES_VERSION}/    
popd

# Nvidia driver
NVIDIA_DRIVER_URL=https://us.download.nvidia.com/tesla/${NVIDIA_VERSION}/NVIDIA-Linux-x86_64-${NVIDIA_VERSION}.run
$COMMON_DIR/download_and_verify.sh $NVIDIA_DRIVER_URL ${CHECKSUM}
bash NVIDIA-Linux-x86_64-${NVIDIA_VERSION}.run --silent --dkms
$COMMON_DIR/write_component_version.sh "NVIDIA" ${NVIDIA_VERSION}
