#!/bin/bash
set -ex

source ${COMMON_DIR}/utilities.sh

# Install gdrcopy
gdrcopy_metadata=$(get_component_config "gdrcopy")
GDRCOPY_VERSION=$(jq -r '.version' <<< $gdrcopy_metadata)
GDRCOPY_SHA256=$(jq -r '.sha256' <<< $gdrcopy_metadata)
GDRCOPY_DISTRIBUTION=$(jq -r '.distribution' <<< $gdrcopy_metadata)

# Install gdrcopy kmod and devel packages from PMC
#tdnf install -y gdrcopy \
#                gdrcopy-kmod \
#              gdrcopy-devel

tdnf -y install /home/packer/azurelinux-hpc/prebuilt/gdrcopy-2.5-4.azl3.x86_64.rpm
tdnf install -y gdrcopy-kmod
tdnf -y install /home/packer/azurelinux-hpc/prebuilt/gdrcopy-devel-2.5-4.azl3.noarch.rpm

$COMMON_DIR/write_component_version.sh "GDRCOPY" ${GDRCOPY_VERSION}
