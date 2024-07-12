#!/bin/bash
set -ex

# Install gdrcopy
apt install -y build-essential devscripts debhelper check libsubunit-dev fakeroot pkg-config dkms

gdrcopy_metadata=$(jq -r '.gdrcopy."'"$DISTRIBUTION"'"' <<< $COMPONENT_VERSIONS)
GDRCOPY_VERSION=$(jq -r '.version' <<< $gdrcopy_metadata)
GDRCOPY_DISTRIBUTION=$(jq -r '.distribution' <<< $gdrcopy_metadata)
TARBALL="v${GDRCOPY_VERSION}.tar.gz"
GDRCOPY_DOWNLOAD_URL=https://github.com/NVIDIA/gdrcopy/archive/refs/tags/${TARBALL}
wget $GDRCOPY_DOWNLOAD_URL
tar -xvf $TARBALL

pushd gdrcopy-${GDRCOPY_VERSION}/packages/
CUDA=/usr/local/cuda ./build-deb-packages.sh 
dpkg -i gdrdrv-dkms_${GDRCOPY_VERSION}-1_amd64.${GDRCOPY_DISTRIBUTION}.deb
apt-mark hold gdrdrv-dkms
dpkg -i libgdrapi_${GDRCOPY_VERSION}-1_amd64.${GDRCOPY_DISTRIBUTION}.deb
apt-mark hold libgdrapi
dpkg -i gdrcopy-tests_${GDRCOPY_VERSION}-1_amd64.${GDRCOPY_DISTRIBUTION}.deb
apt-mark hold gdrcopy-tests
dpkg -i gdrcopy_${GDRCOPY_VERSION}-1_amd64.${GDRCOPY_DISTRIBUTION}.deb
apt-mark hold gdrcopy
popd

$COMMON_DIR/write_component_version.sh "GDRCOPY" ${GDRCOPY_VERSION}