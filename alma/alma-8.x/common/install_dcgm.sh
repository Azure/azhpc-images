#!/bin/bash
set -ex

# Set DCGM version info
dcgm_metadata=$(jq -r '.dcgm."'"$DISTRIBUTION"'"' <<< $COMPONENT_VERSIONS)
dcgm_version=$(jq -r '.version' <<< $dcgm_metadata)
dcgm_distribution=$(jq -r '.distribution' <<< $dcgm_metadata)

# Install DCGM
dnf config-manager --add-repo https://developer.download.nvidia.com/compute/cuda/repos/$dcgm_distribution/x86_64/cuda-$dcgm_distribution.repo
dnf clean expire-cache
dnf install -y datacenter-gpu-manager-1:$dcgm_version
$COMMON_DIR/write_component_version.sh "dcgm" $dcgm_version

# Enable the dcgm service
systemctl --now enable nvidia-dcgm
systemctl start nvidia-dcgm
# Check if the service is active
systemctl is-active --quiet nvidia-dcgm
error_code=$?
if [ $error_code -ne 0 ]
then
    echo "DCGM is inactive!"
    exit $error_code
fi
