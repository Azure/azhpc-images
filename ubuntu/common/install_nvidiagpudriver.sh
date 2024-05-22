#!/bin/bash
set -ex

# Set the driver versions
cuda_metadata=$(jq -r '.cuda."'"$DISTRIBUTION"'"' <<< $COMPONENT_VERSIONS)
CUDA_DRIVER_VERSION=$(jq -r '.driver.version' <<< $cuda_metadata)
CUDA_DRIVER_DISTRIBUTION=$(jq -r '.driver.distribution' <<< $cuda_metadata)
CUDA_SAMPLES_VERSION=$(jq -r '.samples.version' <<< $cuda_metadata)

# Reference - https://docs.nvidia.com/cuda/cuda-installation-guide-linux/index.html#ubuntu-installation
# Install Cuda
wget https://developer.download.nvidia.com/compute/cuda/repos/${CUDA_DRIVER_DISTRIBUTION}/x86_64/cuda-keyring_1.0-1_all.deb
dpkg -i ./cuda-keyring_1.0-1_all.deb

apt-get update
apt install -y cuda-toolkit-${CUDA_DRIVER_VERSION}
echo 'export PATH=$PATH:/usr/local/cuda/bin' | tee -a /etc/bash.bashrc
echo 'export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/cuda/lib64' | tee -a /etc/bash.bashrc
$COMMON_DIR/write_component_version.sh "CUDA" ${CUDA_DRIVER_VERSION}

# Download CUDA samples
TARBALL="v${CUDA_SAMPLES_VERSION}.tar.gz"
CUDA_SAMPLES_DOWNLOAD_URL=https://github.com/NVIDIA/cuda-samples/archive/refs/tags/${TARBALL}
wget ${CUDA_SAMPLES_DOWNLOAD_URL}
tar -xvf ${TARBALL}
pushd ./cuda-samples-${CUDA_SAMPLES_VERSION}
make
mv -vT ./Samples /usr/local/cuda-${CUDA_SAMPLES_VERSION}/samples
popd

# Install NVIDIA driver
nvidia_driver_metadata=$(jq -r '.nvidia."'"$DISTRIBUTION"'".driver' <<< $COMPONENT_VERSIONS)
NVIDIA_DRIVER_VERSION=$(jq -r '.version' <<< $nvidia_driver_metadata)
NVIDIA_DRIVER_SHA256=$(jq -r '.sha256' <<< $nvidia_driver_metadata)
NVIDIA_DRIVER_URL=https://us.download.nvidia.com/tesla/${NVIDIA_DRIVER_VERSION}/NVIDIA-Linux-x86_64-${NVIDIA_DRIVER_VERSION}.run

$COMMON_DIR/download_and_verify.sh $NVIDIA_DRIVER_URL ${NVIDIA_DRIVER_SHA256}
bash NVIDIA-Linux-x86_64-${NVIDIA_DRIVER_VERSION}.run --silent --dkms
$COMMON_DIR/write_component_version.sh "NVIDIA" ${NVIDIA_DRIVER_VERSION}
