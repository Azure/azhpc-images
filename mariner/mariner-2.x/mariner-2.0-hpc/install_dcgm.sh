#!/bin/bash
set -ex

# Set DCGM version info
dcgm_metadata=$(jq -r '.dcgm."'"$DISTRIBUTION"'"' <<< $COMPONENT_VERSIONS)
dcgm_version=$(jq -r '.version' <<< $dcgm_metadata)
dcgm_sha256=$(jq -r '.sha256' <<< $dcgm_metadata)
dcgm_distribution=$(jq -r '.distribution' <<< $dcgm_metadata)

# Install DCGM
dcgm_download_url=https://developer.download.nvidia.com/compute/cuda/repos/$dcgm_distribution/x86_64/datacenter-gpu-manager-$dcgm_version-x86_64.rpm
$COMMON_DIR/download_and_verify.sh $dcgm_download_url $dcgm_sha256
dnf install -y ./datacenter-gpu-manager-$dcgm_version-x86_64.rpm

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

# Clean repos
rm -rf datacenter-gpu-manager*.rpm