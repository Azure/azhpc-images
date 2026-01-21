#!/bin/bash
set -ex

source ${UTILS_DIR}/utilities.sh

# Set CUDA version info
CUDA_VERSION=$(nvidia-smi | sed -E -n 's/.*CUDA Version: ([0-9]+)[.].*/\1/p')


# Install DCGM
# Reference: https://developer.nvidia.com/dcgm#Downloads
# the repo is already added during nvidia/ cuda installations
if [[ $DISTRIBUTION == *"ubuntu"* ]]; then
    apt-get install -y datacenter-gpu-manager
    if [[ "$ARCHITECTURE" == "aarch64" ]]; then
        dcgm_metadata=$(get_component_config "dcgm4")
        DCGM_VERSION=$(jq -r '.version' <<< $dcgm_metadata)
        apt-get install -y datacenter-gpu-manager-4-cuda${CUDA_VERSION}=${DCGM_VERSION} datacenter-gpu-manager-4-core=${DCGM_VERSION}  datacenter-gpu-manager-4-proprietary=${DCGM_VERSION} datacenter-gpu-manager-4-proprietary-cuda${CUDA_VERSION}=${DCGM_VERSION}
    else
        apt-get install -y datacenter-gpu-manager-4-cuda${CUDA_VERSION}
        DCGM_VERSION=$(dcgmi --version | awk '{print $3}')
    fi
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
