#!/bin/bash
set -ex

source ${COMMON_DIR}/utilities.sh

# Set DCGM version info
dcgm_metadata=$(get_component_config "dcgm")
DCGM_VERSION=$(jq -r '.version' <<< $dcgm_metadata)

# Install DCGM
# Reference: https://developer.nvidia.com/dcgm#Downloads
# the repo is already added during nvidia/ cuda installations

tdnf install -y $TOP_DIR/prebuilt/datacenter-gpu-manager-${DCGM_VERSION}-1-x86_64.rpm --nogpgcheck

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
