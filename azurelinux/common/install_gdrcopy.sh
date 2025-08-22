#!/bin/bash
set -ex

source ${COMMON_DIR}/utilities.sh

# Install gdrcopy
gdrcopy_metadata=$(get_component_config "gdrcopy")
GDRCOPY_VERSION=$(jq -r '.version' <<< $gdrcopy_metadata)
GDRCOPY_SHA256=$(jq -r '.sha256' <<< $gdrcopy_metadata)
GDRCOPY_DISTRIBUTION=$(jq -r '.distribution' <<< $gdrcopy_metadata)

kernel_version=$(uname -r | sed 's/\-/./g')
kernel_version=${kernel_version%.*}

nvidia_driver_metadata=$(get_component_config "nvidia")
NVIDIA_DRIVER_VERSION=$(jq -r '.driver.version' <<< $nvidia_driver_metadata)

# Install gdrcopy kmod and devel packages from PMC
tdnf install -y gdrcopy-${GDRCOPY_VERSION}.azl3.x86_64 \
                gdrcopy-kmod-${GDRCOPY_VERSION}_$kernel_version.$NVIDIA_DRIVER_VERSION.azl3.x86_64 \
                gdrcopy-devel-${GDRCOPY_VERSION}.azl3.noarch

$COMMON_DIR/write_component_version.sh "GDRCOPY" ${GDRCOPY_VERSION}
