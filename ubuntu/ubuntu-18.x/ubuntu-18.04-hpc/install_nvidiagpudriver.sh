#!/bin/bash
set -ex

# Reference - https://docs.nvidia.com/cuda/cuda-installation-guide-linux/index.html#ubuntu-installation
# Install Cuda
NVIDIA_VERSION="510.85.02"
CUDA_VERSION="11.6"
wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64/cuda-keyring_1.0-1_all.deb
dpkg -i ./cuda-keyring_1.0-1_all.deb

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

# Install NVIDIA Peer memory
$UBUNTU_COMMON_DIR/install_nv_peer_memory.sh

# Install gdrcopy
sudo apt install -y build-essential devscripts debhelper check libsubunit-dev fakeroot pkg-config dkms
GDRCOPY_VERSION="2.3"
TARBALL="v${GDRCOPY_VERSION}.tar.gz"
GDRCOPY_DOWNLOAD_URL=https://github.com/NVIDIA/gdrcopy/archive/refs/tags/${TARBALL}
wget $GDRCOPY_DOWNLOAD_URL
tar -xvf $TARBALL

pushd gdrcopy-${GDRCOPY_VERSION}/packages/
CUDA=/usr/local/cuda ./build-deb-packages.sh 
sudo dpkg -i gdrdrv-dkms_${GDRCOPY_VERSION}-1_amd64.Ubuntu18_04.deb
sudo apt-mark hold gdrdrv-dkms
sudo dpkg -i libgdrapi_${GDRCOPY_VERSION}-1_amd64.Ubuntu18_04.deb
sudo apt-mark hold libgdrapi
sudo dpkg -i gdrcopy-tests_${GDRCOPY_VERSION}-1_amd64.Ubuntu18_04.deb
sudo apt-mark hold gdrcopy-tests
sudo dpkg -i gdrcopy_${GDRCOPY_VERSION}-1_amd64.Ubuntu18_04.deb
sudo apt-mark hold gdrcopy
popd

$COMMON_DIR/write_component_version.sh "GDRCOPY" ${GDRCOPY_VERSION}
