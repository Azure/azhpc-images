#!/bin/bash
set -ex

source ${COMMON_DIR}/utilities.sh

# Set the driver versions
cuda_metadata=$(get_component_config "cuda")
CUDA_DRIVER_VERSION=$(jq -r '.driver.version' <<< $cuda_metadata)
CUDA_DRIVER_DISTRIBUTION=$(jq -r '.driver.distribution' <<< $cuda_metadata)
CUDA_SAMPLES_VERSION=$(jq -r '.samples.version' <<< $cuda_metadata)
CUDA_SAMPLES_SHA256=$(jq -r '.samples.sha256' <<< $cuda_metadata)

if [ "$1" = "V100" ]; then
    KERNEL_MODULE_TYPE="proprietary"
else
    KERNEL_MODULE_TYPE="open"
fi

# Reference - https://docs.nvidia.com/cuda/cuda-installation-guide-linux/index.html#ubuntu-installation
# Install Cuda
wget https://developer.download.nvidia.com/compute/cuda/repos/${CUDA_DRIVER_DISTRIBUTION}/x86_64/cuda-keyring_1.1-1_all.deb
dpkg -i ./cuda-keyring_1.1-1_all.deb

apt-get update
apt install -y cuda-toolkit-${CUDA_DRIVER_VERSION//./-}
echo 'export PATH=$PATH:/usr/local/cuda/bin' | tee -a /etc/bash.bashrc
echo 'export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/cuda/lib64' | tee -a /etc/bash.bashrc
$COMMON_DIR/write_component_version.sh "CUDA" ${CUDA_DRIVER_VERSION}

# Download CUDA samples
TARBALL="v${CUDA_SAMPLES_VERSION}.tar.gz"
CUDA_SAMPLES_DOWNLOAD_URL=https://github.com/NVIDIA/cuda-samples/archive/refs/tags/${TARBALL}
$COMMON_DIR/download_and_verify.sh ${CUDA_SAMPLES_DOWNLOAD_URL} ${CUDA_SAMPLES_SHA256}
tar -xvf ${TARBALL}
pushd ./cuda-samples-${CUDA_SAMPLES_VERSION}
mkdir build && cd build
cmake -DCMAKE_CUDA_COMPILER=/usr/local/cuda/bin/nvcc ..
make -j $(nproc)
mv -vT ./Samples /usr/local/cuda-${CUDA_DRIVER_VERSION}/samples # Use the same version as the CUDA toolkit as thats where samples is being moved to
popd

# Install NVIDIA driver
nvidia_metadata=$(get_component_config "nvidia")
nvidia_driver_metadata=$(jq -r '.driver' <<< $nvidia_metadata)
NVIDIA_DRIVER_VERSION=$(jq -r '.version' <<< $nvidia_driver_metadata)
NVIDIA_DRIVER_SHA256=$(jq -r '.sha256' <<< $nvidia_driver_metadata)
NVIDIA_DRIVER_URL=https://us.download.nvidia.com/tesla/${NVIDIA_DRIVER_VERSION}/NVIDIA-Linux-x86_64-${NVIDIA_DRIVER_VERSION}.run

$COMMON_DIR/download_and_verify.sh $NVIDIA_DRIVER_URL ${NVIDIA_DRIVER_SHA256}
bash NVIDIA-Linux-x86_64-${NVIDIA_DRIVER_VERSION}.run --silent --dkms --kernel-module-type=${KERNEL_MODULE_TYPE}
$COMMON_DIR/write_component_version.sh "NVIDIA" ${NVIDIA_DRIVER_VERSION}

# load the nvidia-peermem coming as a part of NVIDIA GPU driver
# Reference - https://download.nvidia.com/XFree86/Linux-x86_64/510.85.02/README/nvidia-peermem.html
modprobe nvidia-peermem
# verify if loaded
lsmod | grep nvidia_peermem

touch /etc/modules-load.d/nvidia-peermem.conf
echo "nvidia_peermem" >> /etc/modules-load.d/nvidia-peermem.conf

$UBUNTU_COMMON_DIR/install_gdrcopy.sh

# Install nvidia fabric manager (required for ND96asr_v4)
$UBUNTU_COMMON_DIR/install_nvidia_fabric_manager.sh