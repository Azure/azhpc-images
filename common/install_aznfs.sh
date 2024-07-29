#!/bin/bash
set -ex

# Install AZNFS Mount Helper
aznfs_metadata=$(jq -r '.aznfs."'"$DISTRIBUTION"'"' <<< $COMPONENT_VERSIONS)
AZNFS_VERSION=$(jq -r '.version' <<< $aznfs_metadata)
AZNFS_SHA256=$(jq -r '.sha256' <<< $aznfs_metadata)
AZNFS_DOWNLOAD_URL=https://github.com/Azure/AZNFS-mount/releases/download/${AZNFS_VERSION}/aznfs_install.sh

${COMMON_DIR}/download_and_verify.sh $AZNFS_DOWNLOAD_URL $AZNFS_SHA256

echo Y > /sys/module/sunrpc/parameters/enable_azure_nconnect

export AZNFS_NONINTERACTIVE_INSTALL=1
bash aznfs_install.sh
