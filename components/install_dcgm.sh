#!/bin/bash
set -ex

source ${UTILS_DIR}/utilities.sh

# Set CUDA version info from nvidia-smi (max supported version)
CUDA_VERSION=$(nvidia-smi | sed -E -n 's/.*CUDA Version: ([0-9]+)[.].*/\1/p')

# Check for SKU-specific CUDA version in versions.json that may be lower
cuda_metadata=$(get_component_config "cuda")
SKU_CUDA_VERSION=$(jq -r '.driver.version' <<< $cuda_metadata | cut -d'.' -f1)
# Only set if it's lower than nvidia-smi version
if [[ "${SKU_CUDA_VERSION}" -ge "${CUDA_VERSION}" ]]; then
    SKU_CUDA_VERSION=""
fi

# Install DCGM
# Reference: https://developer.nvidia.com/dcgm#Downloads
# the repo is already added during nvidia/ cuda installations

# Get DCGM version from versions.json
dcgm_metadata=$(get_component_config "dcgm")
DCGM_VERSION=$(jq -r '.version' <<< $dcgm_metadata)

if [[ $DISTRIBUTION == *"ubuntu"* ]]; then
    apt-get install -y \
        datacenter-gpu-manager-4-cuda${CUDA_VERSION}=${DCGM_VERSION} \
        datacenter-gpu-manager-4-core=${DCGM_VERSION} \
        datacenter-gpu-manager-4-proprietary=${DCGM_VERSION} \
        datacenter-gpu-manager-4-proprietary-cuda${CUDA_VERSION}=${DCGM_VERSION}
    # Install DCGM packages for lower SKU-specific CUDA version if exists
    if [[ -n "${SKU_CUDA_VERSION}" ]]; then
        echo "Installing DCGM packages for SKU-specific CUDA ${SKU_CUDA_VERSION}"
        apt-get install -y \
            datacenter-gpu-manager-4-cuda${SKU_CUDA_VERSION}=${DCGM_VERSION} \
            datacenter-gpu-manager-4-core=${DCGM_VERSION} \
            datacenter-gpu-manager-4-proprietary=${DCGM_VERSION} \
            datacenter-gpu-manager-4-proprietary-cuda${SKU_CUDA_VERSION}=${DCGM_VERSION}
    fi
elif [[ $DISTRIBUTION == *"almalinux"* ]]; then
    dnf clean expire-cache
    dnf install --assumeyes --setopt=install_weak_deps=True datacenter-gpu-manager-4-cuda${CUDA_VERSION}
    DCGM_VERSION=$(dcgmi --version | awk '{print $3}')
elif  [[ $DISTRIBUTION == *"azurelinux"* ]]; then
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
