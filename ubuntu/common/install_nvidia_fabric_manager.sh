#!/bin/bash
set -ex

# Set NVIDIA fabricmanager version
nvidia_fabricmanager_metadata=$(jq -r '.nvidia."'"$DISTRIBUTION"'".fabricmanager' <<< $COMPONENT_VERSIONS)
nvidia_fabricmanager_prefix=$(jq -r '.prefix' <<< $nvidia_fabricmanager_metadata)
nvidia_fabricmanager_distribution=$(jq -r '.distribution' <<< $nvidia_fabricmanager_metadata)
nvidia_fabricmanager_version=$(jq -r '.version' <<< $nvidia_fabricmanager_metadata)
nvidia_fabricmanager_sha256=$(jq -r '.sha256' <<< $nvidia_fabricmanager_metadata)

nvidia_fabricmanager_download_url=http://developer.download.nvidia.com/compute/cuda/repos/$nvidia_fabricmanager_distribution/x86_64/nvidia-fabricmanager-${nvidia_fabricmanager_version}_amd64.deb
$COMMON_DIR/download_and_verify.sh $nvidia_fabricmanager_download_url $nvidia_fabricmanager_sha256
apt install -y ./nvidia-fabricmanager-${nvidia_fabricmanager_version}_amd64.deb
apt-mark hold nvidia-fabricmanager-$nvidia_fabricmanager_prefix
$COMMON_DIR/write_component_version.sh "nvidia_fabricmanager" $nvidia_fabricmanager_version
