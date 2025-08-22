#!/bin/bash
set -ex

source ${COMMON_DIR}/utilities.sh

# Set NVIDIA fabricmanager version
nvidia_metadata=$(get_component_config "nvidia")
nvidia_fabricmanager_metadata=$(jq -r '.fabricmanager' <<< $nvidia_metadata)
NVIDIA_FABRICMANAGER_DISTRIBUTION=$(jq -r '.distribution' <<< $nvidia_fabricmanager_metadata)
NVIDIA_FABRICMANAGER_VERSION=$(jq -r '.version' <<< $nvidia_fabricmanager_metadata)
# NVIDIA_FABRICMANAGER_SHA256=$(jq -r '.sha256' <<< $nvidia_fabricmanager_metadata)

# tdnf install -y nvidia-fabric-manager-${NVIDIA_FABRICMANAGER_VERSION}

# Install Nvidia Fabric Manager and devel packages from PMC
tdnf install -y nvidia-fabric-manager-${NVIDIA_FABRICMANAGER_VERSION}-1.azl3.x86_64 \
                nvidia-fabric-manager-devel-${NVIDIA_FABRICMANAGER_VERSION}-1.azl3.x86_64

$COMMON_DIR/write_component_version.sh "NVIDIA_FABRICMANAGER" ${NVIDIA_FABRICMANAGER_VERSION}
