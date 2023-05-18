#!/bin/bash
set -ex

# Install DCGM
# Reference: https://developer.nvidia.com/dcgm#Downloads
# the repo is already added during nvidia/ cuda installations
DCGM_VERSION=3.1.8
dnf clean expire-cache
dnf install -y datacenter-gpu-manager-1:${DCGM_VERSION}
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
