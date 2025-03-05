#!/bin/bash
set -ex

source ${COMMON_DIR}/utilities.sh

# Install gdrcopy
apt install -y build-essential devscripts debhelper check libsubunit-dev fakeroot pkg-config dkms

gdrcopy_metadata=$(get_component_config "gdrcopy")
GDRCOPY_VERSION=$(jq -r '.version' <<< $gdrcopy_metadata)
GDRCOPY_COMMIT=$(jq -r '.commit' <<< $gdrcopy_metadata)
GDRCOPY_DISTRIBUTION=$(jq -r '.distribution' <<< $gdrcopy_metadata)

cuda_metadata=$(get_component_config "cuda")
CUDA_DRIVER_VERSION=$(jq -r '.driver.version' <<< $cuda_metadata)

git clone https://github.com/NVIDIA/gdrcopy.git
pushd gdrcopy/packages/
git checkout ${GDRCOPY_COMMIT}

CUDA=/usr/local/cuda ./build-deb-packages.sh 
dpkg -i gdrdrv-dkms_${GDRCOPY_VERSION}_amd64.${GDRCOPY_DISTRIBUTION}.deb
apt-mark hold gdrdrv-dkms
dpkg -i libgdrapi_${GDRCOPY_VERSION}_amd64.${GDRCOPY_DISTRIBUTION}.deb
apt-mark hold libgdrapi
dpkg -i gdrcopy-tests_${GDRCOPY_VERSION}_amd64.${GDRCOPY_DISTRIBUTION}+cuda${CUDA_DRIVER_VERSION}.deb
apt-mark hold gdrcopy-tests
dpkg -i gdrcopy_${GDRCOPY_VERSION}_amd64.${GDRCOPY_DISTRIBUTION}.deb
apt-mark hold gdrcopy
popd

$COMMON_DIR/write_component_version.sh "GDRCOPY" ${GDRCOPY_VERSION}