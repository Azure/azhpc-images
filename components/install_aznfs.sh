#!/bin/bash
set -ex

source ${UTILS_DIR}/utilities.sh

# Install AZNFS Mount Helper
aznfs_metadata=$(get_component_config "aznfs")
AZNFS_VERSION=$(jq -r '.version' <<< $aznfs_metadata)
AZNFS_SHA256=$(jq -r '.sha256' <<< $aznfs_metadata)
AZNFS_DOWNLOAD_URL=https://github.com/Azure/AZNFS-mount/releases/download/${AZNFS_VERSION}/aznfs_install.sh

download_and_verify $AZNFS_DOWNLOAD_URL $AZNFS_SHA256
if [[ $DISTRIBUTION == "azurelinux3.0" ]]; then
    sed -i 's/yum/tdnf/' aznfs_install.sh
fi

sed -i 's/-o "\$distro" == "ol"/-o "$distro" == "ol" -o "$distro" == "almalinux"/' aznfs_install.sh
export AZNFS_NONINTERACTIVE_INSTALL=1
bash aznfs_install.sh
