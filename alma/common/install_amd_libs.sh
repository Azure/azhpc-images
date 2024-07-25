#!/bin/bash
set -ex

$COMMON_DIR/install_amd_libs.sh

# Set AOCC version
amd_metadata=$(jq -r '.amd."'"$DISTRIBUTION"'"' <<< $COMPONENT_VERSIONS)
AOCC_VERSION=$(jq -r '.aocc.version' <<< $amd_metadata)
AOCC_FOLDER_VERSION=$(echo $AOCC_VERSION | cut -d'.' -f1-2 --output-delimiter='-')

# install dependency
wget https://download.amd.com/developer/eula/aocc/aocc-${AOCC_FOLDER_VERSION}/aocc-compiler-${AOCC_VERSION}.x86_64.rpm
dnf install -y ./aocc-compiler-${AOCC_VERSION}.x86_64.rpm

rm aocc-compiler-${AOCC_VERSION}.x86_64.rpm

$COMMON_DIR/write_component_version.sh "AOCC" ${AOCC_VERSION}
