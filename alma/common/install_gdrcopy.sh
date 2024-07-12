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
CUDA=/usr/local/cuda ./build-rpm-packages.sh
rpm -Uvh gdrcopy-kmod-${GDRCOPY_VERSION}-1dkms.noarch.${GDRCOPY_DISTRIBUTION}.rpm
rpm -Uvh gdrcopy-${GDRCOPY_VERSION}-1.x86_64.${GDRCOPY_DISTRIBUTION}.rpm
rpm -Uvh gdrcopy-devel-${GDRCOPY_VERSION}-1.noarch.${GDRCOPY_DISTRIBUTION}.rpm
sed -i "$ s/$/ gdrcopy*/" /etc/dnf/dnf.conf
popd

$COMMON_DIR/write_component_version.sh "GDRCOPY" ${GDRCOPY_VERSION}
