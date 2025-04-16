#!/bin/bash

set -ex

source ${COMMON_DIR}/utilities.sh

# Set the Moneo version
moneo_metadata=$(get_component_config "moneo")
MONEO_VERSION=$(jq -r '.version' <<< $moneo_metadata)
MONEO_SHA256=$(jq -r '.sha256' <<< $moneo_metadata)

# Dependencies 
python3 -m pip install --upgrade pip

MONITOR_DIR=/opt/azurehpc/tools
TARBALL="v${MONEO_VERSION}.tar.gz"
MONEO_DOWNLOAD_URL=https://github.com/Azure/Moneo/archive/refs/tags/${TARBALL}
$COMMON_DIR/download_and_verify.sh ${MONEO_DOWNLOAD_URL} ${MONEO_SHA256} $MONITOR_DIR

pushd $MONITOR_DIR
    mkdir Moneo && tar -xvf $TARBALL --strip-components=1 -C Moneo  
    chmod 777 Moneo
    pushd Moneo/linux_service
        ./configure_service.sh   
    popd
popd

# add an alias for Moneo
if ! grep -qxF "alias moneo='python3 /opt/azurehpc/tools/Moneo/moneo.py'" /etc/bash.bashrc; then
    echo "alias moneo='python3 /opt/azurehpc/tools/Moneo/moneo.py'" >> /etc/bash.bashrc
fi

$COMMON_DIR/write_component_version.sh "MONEO" ${MONEO_VERSION}
