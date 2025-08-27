#!/bin/bash
set -ex

source ${COMMON_DIR}/utilities.sh

# Install AZNFS Mount Helper
# prefer PMC when possible
if [[ $DISTRIBUTION == *"ubuntu"* ]]
then
    apt install -y aznfs
elif [[ $DISTRIBUTION == *"almalinux"* || $DISTRIBUTION == *"rhel"* ]]
then
    dnf install -y aznfs
elif [[ $DISTRIBUTION == *"azurelinux"* ]]
then
    aznfs_metadata=$(get_component_config "aznfs")
    AZNFS_VERSION=$(jq -r '.version' <<< $aznfs_metadata)
    AZNFS_SHA256=$(jq -r '.sha256' <<< $aznfs_metadata)
    AZNFS_DOWNLOAD_URL=https://github.com/Azure/AZNFS-mount/releases/download/${AZNFS_VERSION}/aznfs_install.sh

    ${COMMON_DIR}/download_and_verify.sh $AZNFS_DOWNLOAD_URL $AZNFS_SHA256
    sed -i 's/yum/tdnf/' aznfs_install.sh
    export AZNFS_NONINTERACTIVE_INSTALL=1
    bash aznfs_install.sh
fi

