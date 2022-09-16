#!/bin/bash
set -ex

# Parameters
RELEASE_VERSION=$1
CHECKSUM=$2

# Reference - https://docs.nvidia.com/cuda/cuda-installation-guide-linux/index.html#ubuntu-installation
# Install Cuda
NVIDIA_VERSION="510.85.02"
if [ ${RELEASE_VERSION} == "1804" ]; then CUDA_VERSION="11.6"; else CUDA_VERSION="11-6"; fi
wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu${RELEASE_VERSION}/x86_64/cuda-ubuntu${RELEASE_VERSION}-keyring.gpg 
mv cuda-ubuntu${RELEASE_VERSION}-keyring.gpg /usr/share/keyrings/cuda-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/cuda-archive-keyring.gpg] https://developer.download.nvidia.com/compute/cuda/repos/ubuntu${RELEASE_VERSION}/x86_64/ /" | sudo tee /etc/apt/sources.list.d/cuda-ubuntu${RELEASE_VERSION}-x86_64.list
wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu${RELEASE_VERSION}/x86_64/cuda-ubuntu${RELEASE_VERSION}.pin
mv cuda-ubuntu${RELEASE_VERSION}.pin /etc/apt/preferences.d/cuda-repository-pin-600

apt-get update
apt install -y cuda-toolkit-${CUDA_VERSION}
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
NVIDIA_DRIVER_URL=https://us.download.nvidia.com/tesla/${NVIDIA_VERSION}/NVIDIA-Linux-x86_64-${NVIDIA_VERSION}.run
$COMMON_DIR/download_and_verify.sh $NVIDIA_DRIVER_URL "372427e633f32cff6dd76020e8ed471ef825d38878bd9655308b6efea1051090"
bash NVIDIA-Linux-x86_64-${NVIDIA_VERSION}.run --silent --dkms
$COMMON_DIR/write_component_version.sh "NVIDIA" ${NVIDIA_VERSION}

# remove keyring and repo files
rm -rf /usr/share/keyrings/cuda-archive-keyring.gpg
rm -rf /etc/apt/preferences.d/cuda-repository-pin-600
