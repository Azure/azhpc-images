#!/bin/bash
set -ex

source ${COMMON_DIR}/utilities.sh

# Set CUDA version info
CUDA_VERSION=$(nvidia-smi | sed -E -n 's/.*CUDA Version: ([0-9]+)[.].*/\1/p')

# Install DCGM
# Reference: https://developer.nvidia.com/dcgm#Downloads
# the repo is already added during nvidia/ cuda installations
dnf clean expire-cache
dnf install --assumeyes --setopt=install_weak_deps=True datacenter-gpu-manager-4-cuda${CUDA_VERSION}

DCGM_VERSION=$(dcgmi --version | awk '{print $3}')
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
