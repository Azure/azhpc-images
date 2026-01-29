#!/bin/bash

set -ex

source ${UTILS_DIR}/utilities.sh

# Set the Moneo version
moneo_metadata=$(get_component_config "moneo")
MONEO_VERSION=$(jq -r '.version' <<< $moneo_metadata)
MONEO_SHA256=$(jq -r '.sha256' <<< $moneo_metadata)

# Dependencies 
if [[ $DISTRIBUTION == "azurelinux3.0" ]]; then
    tdnf install -y python3-pip
elif [[ $DISTRIBUTION == "ubuntu24.04" ]]; then
    apt-get install -y --only-upgrade python3-pip
else
    python3 -m pip install --upgrade pip
fi

MONITOR_DIR=/opt/azurehpc/tools
TARBALL="v${MONEO_VERSION}.tar.gz"
MONEO_DOWNLOAD_URL=https://github.com/Azure/Moneo/archive/refs/tags/${TARBALL}
download_and_verify ${MONEO_DOWNLOAD_URL} ${MONEO_SHA256} $MONITOR_DIR

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

write_component_version "MONEO" ${MONEO_VERSION}
