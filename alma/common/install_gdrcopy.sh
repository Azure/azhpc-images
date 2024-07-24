#!/bin/bash
set -ex

# Install gdrcopy
gdrcopy_metadata=$(jq -r '.gdrcopy."'"$DISTRIBUTION"'"' <<< $COMPONENT_VERSIONS)
GDRCOPY_VERSION=$(jq -r '.version' <<< $gdrcopy_metadata)
GDRCOPY_SHA256=$(jq -r '.sha256' <<< $gdrcopy_metadata)
GDRCOPY_DISTRIBUTION=$(jq -r '.distribution' <<< $gdrcopy_metadata)

TARBALL="v${GDRCOPY_VERSION}.tar.gz"
GDRCOPY_DOWNLOAD_URL=https://github.com/NVIDIA/gdrcopy/archive/refs/tags/${TARBALL}

${COMMON_DIR}/download_and_verify.sh $GDRCOPY_DOWNLOAD_URL $GDRCOPY_SHA256
tar -xvf $TARBALL

pushd gdrcopy-${GDRCOPY_VERSION}/packages/
CUDA=/usr/local/cuda ./build-rpm-packages.sh
rpm -Uvh gdrcopy-kmod-${GDRCOPY_VERSION}dkms.noarch.${GDRCOPY_DISTRIBUTION}.rpm
rpm -Uvh gdrcopy-${GDRCOPY_VERSION}.x86_64.${GDRCOPY_DISTRIBUTION}.rpm
rpm -Uvh gdrcopy-devel-${GDRCOPY_VERSION}.noarch.${GDRCOPY_DISTRIBUTION}.rpm
sed -i "$ s/$/ gdrcopy*/" /etc/dnf/dnf.conf
popd

$COMMON_DIR/write_component_version.sh "GDRCOPY" ${GDRCOPY_VERSION}
