#!/bin/bash
set -ex

# Set DCGM version info
dcgm_metadata=$(jq -r '.dcgm."'"$DISTRIBUTION"'"' <<< $COMPONENT_VERSIONS)
DCGM_VERSION=$(jq -r '.version' <<< $dcgm_metadata)

# Install DCGM
# Reference: https://developer.nvidia.com/dcgm#Downloads
# the repo is already added during nvidia/ cuda installations
apt-get install -y datacenter-gpu-manager=1:${DCGM_VERSION}
$COMMON_DIR/write_component_version.sh "DCGM" ${DCGM_VERSION}

# Enable the dcgm service
systemctl --now enable nvidia-dcgm
systemctl start nvidia-dcgm
# Check if the service is active
systemctl is-active --quiet nvidia-dcgm
error_code=$?
if [ ${error_code} -ne 0 ]
then
    echo "DCGM is inactive!"
    exit ${error_code}
fi
