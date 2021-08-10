#!/bin/bash
set -ex

$UBUNTU_COMMON_DIR/install_nvidiagpudriver.sh

# Install gdrcopy
sudo apt install -y build-essential devscripts debhelper check libsubunit-dev fakeroot pkg-config dkms
GDRCOPY_VERSION="2.3"
$COMMON_DIR/write_component_version.sh "GDRCOPY" ${GDRCOPY_VERSION}
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

# Install nvidia fabric manager (required for ND96asr_v4)
NVIDIA_FABRIC_MANAGER_VERSION="460_460.32.03-1"
$COMMON_DIR/write_component_version.sh "NVIDIA_FABRIC_MANAGER" ${NVIDIA_FABRIC_MANAGER_VERSION}
NVIDIA_FABRIC_MNGR_URL=http://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64/nvidia-fabricmanager-${NVIDIA_FABRIC_MANAGER_VERSION}_amd64.deb
$COMMON_DIR/download_and_verify.sh $NVIDIA_FABRIC_MNGR_URL "157da63c4f7823bb5ae4428891978345a079830629e23579e0c3126f42a4411c"
apt install -y ./nvidia-fabricmanager-${NVIDIA_FABRIC_MANAGER_VERSION}_amd64.deb
sudo apt-mark hold nvidia-fabricmanager-460
systemctl enable nvidia-fabricmanager
systemctl start nvidia-fabricmanager
