#!/bin/bash
set -ex

# Set NVIDIA fabricmanager version
nvidia_fabricmanager_metadata=$(jq -r '.nvidia."'"$DISTRIBUTION"'".fabricmanager' <<< $COMPONENT_VERSIONS)
NVIDIA_FABRICMANAGER_PREFIX=$(jq -r '.prefix' <<< $nvidia_fabricmanager_metadata)
NVIDIA_FABRICMANAGER_DISTRIBUTION=$(jq -r '.distribution' <<< $nvidia_fabricmanager_metadata)
NVIDIA_FABRICMANAGER_VERSION=$(jq -r '.version' <<< $nvidia_fabricmanager_metadata)
NVIDIA_FABRICMANAGER_SHA256=$(jq -r '.sha256' <<< $nvidia_fabricmanager_metadata)

NVIDIA_FABRIC_MNGR_URL=http://developer.download.nvidia.com/compute/cuda/repos/${NVIDIA_FABRICMANAGER_DISTRIBUTION}/x86_64/nvidia-fabricmanager-${NVIDIA_FABRICMANAGER_VERSION}_amd64.deb
$COMMON_DIR/download_and_verify.sh $NVIDIA_FABRIC_MNGR_URL ${NVIDIA_FABRICMANAGER_SHA256}
apt install -y ./nvidia-fabricmanager-${NVIDIA_FABRICMANAGER_VERSION}_amd64.deb
apt-mark hold nvidia-fabricmanager-${NVIDIA_FABRICMANAGER_PREFIX}
$COMMON_DIR/write_component_version.sh "NVIDIA_FABRIC_MANAGER" ${NVIDIA_FABRICMANAGER_VERSION}

systemctl enable nvidia-fabricmanager
systemctl start nvidia-fabricmanager
systemctl is-active --quiet nvidia-fabricmanager
