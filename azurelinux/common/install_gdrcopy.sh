#!/bin/bash
set -ex

source ${COMMON_DIR}/utilities.sh

# Install gdrcopy
gdrcopy_metadata=$(get_component_config "gdrcopy")
GDRCOPY_VERSION=$(jq -r '.version' <<< $gdrcopy_metadata)
GDRCOPY_SHA256=$(jq -r '.sha256' <<< $gdrcopy_metadata)
GDRCOPY_DISTRIBUTION=$(jq -r '.distribution' <<< $gdrcopy_metadata)

# Install gdrcopy kmod and devel packages from PMC
tdnf install -y gdrcopy \
                gdrcopy-kmod \
                gdrcopy-devel

$COMMON_DIR/write_component_version.sh "GDRCOPY" ${GDRCOPY_VERSION}
