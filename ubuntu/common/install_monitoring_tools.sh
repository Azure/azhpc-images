#!/bin/bash

set -e

# Set the Moneo version
MONEO_VERSION=$(jq -r '.moneo."'"$DISTRIBUTION"'".version' <<< $COMPONENT_VERSIONS)

# Dependencies 
python3 -m pip install --upgrade pip

MONITOR_DIR=/opt/azurehpc/tools

mkdir -p $MONITOR_DIR

pushd $MONITOR_DIR

    git clone https://github.com/Azure/Moneo  --branch v$MONEO_VERSION

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
