#!/bin/bash
set -ex

# Set AOCC version
amd_metadata=$(jq -r '.amd."'"$DISTRIBUTION"'"' <<< $COMPONENT_VERSIONS)
AOCC_VERSION=$(jq -r '.aocc.version' <<< $amd_metadata)
AOCC_SHA256=$(jq -r '.aocc.sha256' <<< $amd_metadata)

# install dependency
PACKAGE="aocc-compiler-${AOCC_VERSION}.x86_64.rpm"
AOCC_DOWNLOAD_URL=https://download.amd.com/developer/eula/aocc-compiler/$PACKAGE
$COMMON_DIR/download_and_verify.sh $AOCC_DOWNLOAD_URL $AOCC_SHA256 
tdnf install -y ./$PACKAGE

rm ./$PACKAGE
$COMMON_DIR/write_component_version.sh "AOCC" ${AOCC_VERSION}
