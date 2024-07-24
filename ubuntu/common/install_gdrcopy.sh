#!/bin/bash
set -ex

# Install gdrcopy
apt install -y build-essential devscripts debhelper check libsubunit-dev fakeroot pkg-config dkms

gdrcopy_metadata=$(jq -r '.gdrcopy."'"$DISTRIBUTION"'"' <<< $COMPONENT_VERSIONS)
GDRCOPY_VERSION=$(jq -r '.version' <<< $gdrcopy_metadata)
GDRCOPY_SHA256=$(jq -r '.sha256' <<< $gdrcopy_metadata)
GDRCOPY_DISTRIBUTION=$(jq -r '.distribution' <<< $gdrcopy_metadata)

TARBALL="v${GDRCOPY_VERSION}.tar.gz"
GDRCOPY_DOWNLOAD_URL=https://github.com/NVIDIA/gdrcopy/archive/refs/tags/${TARBALL}

${COMMON_DIR}/download_and_verify.sh $GDRCOPY_DOWNLOAD_URL $GDRCOPY_SHA256
tar -xvf $TARBALL

pushd gdrcopy-${GDRCOPY_VERSION}/packages/
CUDA=/usr/local/cuda ./build-deb-packages.sh 
dpkg -i gdrdrv-dkms_${GDRCOPY_VERSION}_amd64.${GDRCOPY_DISTRIBUTION}.deb
apt-mark hold gdrdrv-dkms
dpkg -i libgdrapi_${GDRCOPY_VERSION}_amd64.${GDRCOPY_DISTRIBUTION}.deb
apt-mark hold libgdrapi
dpkg -i gdrcopy-tests_${GDRCOPY_VERSION}_amd64.${GDRCOPY_DISTRIBUTION}.deb
apt-mark hold gdrcopy-tests
dpkg -i gdrcopy_${GDRCOPY_VERSION}_amd64.${GDRCOPY_DISTRIBUTION}.deb
apt-mark hold gdrcopy
popd

$COMMON_DIR/write_component_version.sh "GDRCOPY" ${GDRCOPY_VERSION}