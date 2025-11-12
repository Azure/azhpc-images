#!/bin/bash
set -ex

source ${UTILS_DIR}/utilities.sh

# Set NVIDIA fabricmanager version
nvidia_metadata=$(get_component_config "nvidia")
nvidia_fabricmanager_metadata=$(jq -r '.fabricmanager' <<< $nvidia_metadata)
NVIDIA_FABRICMANAGER_DISTRIBUTION=$(jq -r '.distribution' <<< $nvidia_fabricmanager_metadata)
NVIDIA_FABRICMANAGER_VERSION=$(jq -r '.version' <<< $nvidia_fabricmanager_metadata)
NVIDIA_FABRICMANAGER_SHA256=$(jq -r '.sha256' <<< $nvidia_fabricmanager_metadata)
NVIDIA_FABRICMANAGER_PREFIX=$(echo $NVIDIA_FABRICMANAGER_VERSION | cut -d '.' -f1)

if [[ $DISTRIBUTION == *"ubuntu"* ]]; then
    # Use different URL format for NVIDIA Fabric Manager major version 580 and above
    if [[ $NVIDIA_FABRICMANAGER_PREFIX -ge 580 ]]; then
        PACKAGE_NAME="nvidia-fabricmanager"
    else
        PACKAGE_NAME="nvidia-fabricmanager-${NVIDIA_FABRICMANAGER_PREFIX}"
    fi

    NVIDIA_FABRIC_MNGR_PKG=http://developer.download.nvidia.com/compute/cuda/repos/${NVIDIA_FABRICMANAGER_DISTRIBUTION}/x86_64/${PACKAGE_NAME}_${NVIDIA_FABRICMANAGER_VERSION}_amd64.deb
    FILENAME=$(basename $NVIDIA_FABRIC_MNGR_PKG)
    download_and_verify ${NVIDIA_FABRIC_MNGR_PKG} ${NVIDIA_FABRICMANAGER_SHA256}

    apt install -y ./${FILENAME}
    apt-mark hold $PACKAGE_NAME
elif [[ $DISTRIBUTION == almalinux* ]]; then    
    NVIDIA_FABRIC_MNGR_PKG=http://developer.download.nvidia.com/compute/cuda/repos/${NVIDIA_FABRICMANAGER_DISTRIBUTION}/x86_64/nvidia-fabric-manager-${NVIDIA_FABRICMANAGER_VERSION}.x86_64.rpm
    FILENAME=$(basename $NVIDIA_FABRIC_MNGR_PKG)
    download_and_verify ${NVIDIA_FABRIC_MNGR_PKG} ${NVIDIA_FABRICMANAGER_SHA256}
    
    yum install -y ./${FILENAME}
    sed -i "$ s/$/ nvidia-fabric-manager/" /etc/dnf/dnf.conf
elif [[ $DISTRIBUTION == "azurelinux3.0" ]]; then
    # Install Nvidia Fabric Manager and devel packages from PMC
    tdnf install -y nvidia-fabric-manager-${NVIDIA_FABRICMANAGER_VERSION}.azl3.x86_64 \
                    nvidia-fabric-manager-devel-${NVIDIA_FABRICMANAGER_VERSION}.azl3.x86_64
fi
write_component_version "NVIDIA_FABRIC_MANAGER" ${NVIDIA_FABRICMANAGER_VERSION}
