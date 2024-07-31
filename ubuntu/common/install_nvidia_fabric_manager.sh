#!/bin/bash
set -ex

source ${COMMON_DIR}/utilities.sh

# Set NVIDIA fabricmanager version
nvidia_metadata=$(get_component_config "nvidia")
nvidia_fabricmanager_metadata=$(jq -r '.fabricmanager' <<< $nvidia_metadata)
NVIDIA_FABRICMANAGER_DISTRIBUTION=$(jq -r '.distribution' <<< $nvidia_fabricmanager_metadata)
NVIDIA_FABRICMANAGER_VERSION=$(jq -r '.version' <<< $nvidia_fabricmanager_metadata)
NVIDIA_FABRICMANAGER_SHA256=$(jq -r '.sha256' <<< $nvidia_fabricmanager_metadata)

NVIDIA_FABRICMANAGER_PREFIX=$(echo $NVIDIA_FABRICMANAGER_VERSION | cut -d '.' -f1)
NVIDIA_FABRIC_MNGR_PKG=http://developer.download.nvidia.com/compute/cuda/repos/${NVIDIA_FABRICMANAGER_DISTRIBUTION}/x86_64/nvidia-fabricmanager-${NVIDIA_FABRICMANAGER_PREFIX}_${NVIDIA_FABRICMANAGER_VERSION}_amd64.deb
FILENAME=$(basename $NVIDIA_FABRIC_MNGR_PKG)

$COMMON_DIR/download_and_verify.sh ${NVIDIA_FABRIC_MNGR_PKG} ${NVIDIA_FABRICMANAGER_SHA256}
apt install -y ./${FILENAME}
apt-mark hold nvidia-fabricmanager-${NVIDIA_FABRICMANAGER_PREFIX}
$COMMON_DIR/write_component_version.sh "NVIDIA_FABRIC_MANAGER" ${NVIDIA_FABRICMANAGER_VERSION}
