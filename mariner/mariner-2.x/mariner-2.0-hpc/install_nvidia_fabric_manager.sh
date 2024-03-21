#!/bin/bash
set -ex

# Set NVIDIA fabricmanager version
nvidia_fabricmanager_metadata=$(jq -r '.nvidia."'"$DISTRIBUTION"'".fabricmanager' <<< $COMPONENT_VERSIONS)
nvidia_fabricmanager_version=$(jq -r '.version' <<< $nvidia_fabricmanager_metadata)

tdnf install -y nvidia-fabric-manager-$nvidia_fabricmanager_version
sed -i "$ s/$/ nvidia-fabric-manager/" /etc/dnf/dnf.conf
$COMMON_DIR/write_component_version.sh "nvidia_fabricmanager" $nvidia_fabricmanager_version
