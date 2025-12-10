#!/bin/bash
set -ex

source ${UTILS_DIR}/utilities.sh


if [[ "$DISTRIBUTION" == ubuntu2*-aks ]]; then
    # Install gdrcopy
    apt install -y build-essential devscripts debhelper check libsubunit-dev fakeroot pkg-config dkms

    gdrcopy_metadata=$(get_component_config "gdrcopy")
    GDRCOPY_VERSION=$(jq -r '.version' <<< $gdrcopy_metadata)
    GDRCOPY_COMMIT=$(jq -r '.commit' <<< $gdrcopy_metadata)
    GDRCOPY_DISTRIBUTION=$(jq -r '.distribution' <<< $gdrcopy_metadata)

    cuda_metadata=$(get_component_config "cuda")
    CUDA_DRIVER_VERSION=$(jq -r '.driver.version' <<< $cuda_metadata)


    wget https://developer.download.nvidia.com/compute/redist/gdrcopy/CUDA%20${CUDA_DRIVER_VERSION}/${GDRCOPY_DISTRIBUTION,}/${ARCH}/gdrdrv-dkms_${GDRCOPY_VERSION}_arm64.${GDRCOPY_DISTRIBUTION}.deb
    dpkg -i gdrdrv-dkms_${GDRCOPY_VERSION}_arm64.${GDRCOPY_DISTRIBUTION}.deb

    write_component_version "GDRCOPY" ${GDRCOPY_VERSION}
fi    