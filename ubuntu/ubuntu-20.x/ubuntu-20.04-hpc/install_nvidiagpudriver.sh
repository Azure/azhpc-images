#!/bin/bash
set -ex

$COMMON_DIR/install_nvidiagpudriver.sh

# Install gdrcopy
gdrcopy_version=$(jq -r '.gdrcopy."'"$DISTRIBUTION"'".version' <<< $COMPONENT_VERSIONS)
spack add gdrcopy@$gdrcopy_version
spack install
$COMMON_DIR/write_component_version.sh "gdrcopy" $gdrcopy_version

# Install nvidia fabric manager (required for ND96asr_v4)
$UBUNTU_COMMON_DIR/install_nvidia_fabric_manager.sh
