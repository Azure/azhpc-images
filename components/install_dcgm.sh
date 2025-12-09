#!/bin/bash
set -ex

source ${UTILS_DIR}/utilities.sh

# Set CUDA version info
cuda_lib_version=$(nvidia-smi | sed -E -n 's/.*CUDA Version: ([0-9]+)[.].*/\1/p')
cuda_toolkit_version=$(nvcc --version | sed -E -n 's/.*release ([0-9]+)[.].*/\1/p')

# Nvidia documentation says that "Generally speaking, users should install binaries targeting the major version of the CUDA user-mode driver that’s installed on their system."
# but that v100 "is not supported by version 13.0.0 of the CUDA Toolkit. Consequently, Maxwell, Volta, and Pascal systems using driver version 580 should install DCGM packages targeting major version 12
# of the user-mode driver (e.g. datacenter-gpu-manager-4-cuda12) rather than DCGM packages targeting major version 13."
if [[${SKU,,} == "v100" ]]; then
    CUDA_VERSION=$cuda_toolkit_version
else
    CUDA_VERSION=$cuda_lib_version
fi

# Install DCGM
# Reference: https://developer.nvidia.com/dcgm#Downloads
# the repo is already added during nvidia/ cuda installations
if [[ $DISTRIBUTION == *"ubuntu"* ]]; then
    apt-get install -y datacenter-gpu-manager
    apt-get install -y datacenter-gpu-manager-4-cuda${CUDA_VERSION}
    DCGM_VERSION=$(dcgmi --version | awk '{print $3}')
elif [[ $DISTRIBUTION == *"almalinux"* ]]; then
    dnf clean expire-cache
    dnf install --assumeyes --setopt=install_weak_deps=True datacenter-gpu-manager-4-cuda${CUDA_VERSION}
    DCGM_VERSION=$(dcgmi --version | awk '{print $3}')
elif  [[ $DISTRIBUTION == *"azurelinux"* ]]; then
    # Set DCGM version info
    dcgm_metadata=$(get_component_config "dcgm")
    DCGM_VERSION=$(jq -r '.version' <<< $dcgm_metadata)
    tdnf install -y $TOP_DIR/prebuilt/datacenter-gpu-manager-${DCGM_VERSION}-1-x86_64.rpm --nogpgcheck
fi

write_component_version "DCGM" ${DCGM_VERSION}

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
