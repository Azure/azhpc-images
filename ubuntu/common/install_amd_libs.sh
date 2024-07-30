#!/bin/bash
set -ex

source ${COMMON_DIR}/utilities.sh

$COMMON_DIR/install_amd_libs.sh

# Set AOCC version
amd_metadata=$(get_component_config "amd")
AOCC_VERSION=$(jq -r '.aocc.version' <<< $amd_metadata)

# install dependency
wget https://download.amd.com/developer/eula/aocc-compiler/aocc-compiler-${AOCC_VERSION}_amd64.deb
apt install -y ./aocc-compiler-${AOCC_VERSION}_amd64.deb

rm aocc-compiler-${AOCC_VERSION}_amd64.deb 

$COMMON_DIR/write_component_version.sh "AOCC" ${AOCC_VERSION}
