#!/bin/bash
set -ex

source ${UTILS_DIR}/utilities.sh

# Set CUDA version info from nvidia-smi (max supported version)
CUDA_VERSION=$(nvidia-smi | sed -E -n 's/.*CUDA Version: ([0-9]+)[.].*/\1/p')

# Check for SKU-specific CUDA version in versions.json that may be lower
cuda_metadata=$(get_component_config "cuda")
SKU_CUDA_VERSION=$(jq -r '.driver.version' <<< $cuda_metadata | cut -d'.' -f1)

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

    # Nvidia documentation says that "Generally speaking, users should install binaries targeting the major version of the CUDA user-mode driver that's installed on their system."
    # but that v100 "is not supported by version 13.0.0 of the CUDA Toolkit. Consequently, Maxwell, Volta, and Pascal systems using driver version 580 should install DCGM packages targeting major version 12
    # of the user-mode driver (e.g. datacenter-gpu-manager-4-cuda12) rather than DCGM packages targeting major version 13."
    # In practice though, DCGM requires both cuda12 and cuda13 support packages (https://github.com/NVIDIA/DCGM/issues/254).
    if [[ "${SKU_CUDA_VERSION}" -lt "${CUDA_VERSION}" ]]; then
        echo "Installing DCGM packages for SKU-specific CUDA ${SKU_CUDA_VERSION}"
        apt-get install -y \
            datacenter-gpu-manager-4-cuda${SKU_CUDA_VERSION}=${DCGM_VERSION} \
            datacenter-gpu-manager-4-proprietary-cuda${SKU_CUDA_VERSION}=${DCGM_VERSION}
    fi
elif [[ $DISTRIBUTION == *"azurelinux"* ]]; then
    # V100 does not support CUDA 13.0
    # so use DCGM compatible with CUDA 12
    if [ "$1" = "V100" ]; then
        tdnf install -y datacenter-gpu-manager-4-cuda12-${DCGM_VERSION}
    else
        tdnf install -y datacenter-gpu-manager-4-cuda13-${DCGM_VERSION}
    fi
else
    # RHEL-family: AlmaLinux, Rocky Linux, RHEL, etc.
    dnf clean expire-cache
    dnf install --assumeyes --setopt=install_weak_deps=True datacenter-gpu-manager-4-cuda${CUDA_VERSION}
    # V100 needs cuda12 DCGM packages in addition to cuda13 (same as Ubuntu logic above)
    if [[ "${SKU_CUDA_VERSION}" -lt "${CUDA_VERSION}" ]]; then
        echo "Installing DCGM packages for SKU-specific CUDA ${SKU_CUDA_VERSION}"
        dnf install --assumeyes --setopt=install_weak_deps=True datacenter-gpu-manager-4-cuda${SKU_CUDA_VERSION}
    fi
    DCGM_VERSION=$(dcgmi --version | awk '{print $3}')
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
