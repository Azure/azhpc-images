#!/bin/bash
set -ex

source ${UTILS_DIR}/utilities.sh

nvidia_metadata=$(get_component_config "nvidia")

if [[ $DISTRIBUTION == *"ubuntu"* ]]; then
    # Install from NVIDIA APT repo (already configured during driver installation)
    # Pinning package ensures the correct version is installed
    NVIDIA_DRIVER_VERSION=$(jq -r '.driver.version' <<< $nvidia_metadata)
    NVIDIA_DRIVER_MAJOR=$(echo $NVIDIA_DRIVER_VERSION | cut -d '.' -f1)

    if [[ $NVIDIA_DRIVER_MAJOR -ge 580 ]]; then
        PACKAGE_NAME="nvidia-fabricmanager"
    else
        PACKAGE_NAME="nvidia-fabricmanager-${NVIDIA_DRIVER_MAJOR}"
    fi

    apt install -y ${PACKAGE_NAME}

    # Read back installed version for the component manifest
    NVIDIA_FABRICMANAGER_VERSION=$(dpkg-query -W -f='${Version}' ${PACKAGE_NAME})
elif [[ $DISTRIBUTION == "azurelinux3.0" ]]; then
    # tdnf does not respect exclude= directive of repo config
    dnf install -y nvidia-fabric-manager \
                   nvidia-fabric-manager-devel \
                   libnvidia-nscq
    NVIDIA_FABRICMANAGER_VERSION=$(sudo tdnf list installed | grep -i nvidia-fabric-manager.x86_64 | sed 's/.*[[:space:]]\([0-9.]*-[0-9]*\)\..*/\1/')
else
    # RHEL-family: AlmaLinux, Rocky Linux, RHEL, etc.
    nvidia_fabricmanager_metadata=$(jq -r '.fabricmanager' <<< $nvidia_metadata)
    NVIDIA_FABRICMANAGER_DISTRIBUTION=$(jq -r '.distribution' <<< $nvidia_fabricmanager_metadata)
    NVIDIA_FABRICMANAGER_VERSION=$(jq -r '.version' <<< $nvidia_fabricmanager_metadata)
    NVIDIA_FABRICMANAGER_SHA256=$(jq -r '.sha256' <<< $nvidia_fabricmanager_metadata)
    NVIDIA_FABRICMANAGER_PREFIX=$(echo $NVIDIA_FABRICMANAGER_VERSION | cut -d '.' -f1)

    # For NVIDIA Fabric Manager major version 580, Nvidia dropped the hyphen between fabric and manager
    if [[ $NVIDIA_FABRICMANAGER_PREFIX -ge 580 ]]; then
        PACKAGE_NAME="nvidia-fabricmanager"
    else
        PACKAGE_NAME="nvidia-fabric-manager"
    fi
    NVIDIA_FABRIC_MNGR_PKG=https://developer.download.nvidia.com/compute/cuda/repos/${NVIDIA_FABRICMANAGER_DISTRIBUTION}/x86_64/${PACKAGE_NAME}-${NVIDIA_FABRICMANAGER_VERSION}.x86_64.rpm
    FILENAME=$(basename $NVIDIA_FABRIC_MNGR_PKG)
    download_and_verify ${NVIDIA_FABRIC_MNGR_PKG} ${NVIDIA_FABRICMANAGER_SHA256}
    
    yum install -y ./${FILENAME}

    # Prevent package from being updated after installation
    sed -i "$ s/$/ ${PACKAGE_NAME}/" /etc/dnf/dnf.conf
fi
write_component_version "NVIDIA_FABRIC_MANAGER" ${NVIDIA_FABRICMANAGER_VERSION}
