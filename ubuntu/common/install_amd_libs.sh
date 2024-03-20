#!/bin/bash

# Set AOCC and AOCL versions
amd_metadata=$(jq -r '.amd."'"$DISTRIBUTION"'"' <<< $COMPONENT_VERSIONS)
AOCC_VERSION=$(jq -r '.aocc.version' <<< $amd_metadata)

# install dependency
wget https://download.amd.com/developer/eula/aocc-compiler/aocc-compiler-${AOCC_VERSION}_amd64.deb
apt install -y ./aocc-compiler-${AOCC_VERSION}_amd64.deb

rm aocc-compiler-${AOCC_VERSION}_amd64.deb 

$COMMON_DIR/write_component_version.sh "AOCC" ${AOCC_VERSION}
