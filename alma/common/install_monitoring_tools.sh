#!/bin/bash

set -e

# grab latest release version
repo=Azure/Moneo
release_version=$(curl -s "https://api.github.com/repos/$repo/releases/latest" | jq -r '.tag_name')

MONEO_VERSION=$release_version

# Dependencies 
python3 -m pip install --upgrade pip

# Adding path to sudo user
sed -i 's/.*secure_path.*/Defaults    secure_path = "\/usr\/local\/sbin:\/usr\/local\/bin:\/sbin:\/bin:\/usr\/sbin:\/usr\/bin\/"/' /etc/sudoers

MONITOR_DIR=/opt/azurehpc/tools

mkdir -p $MONITOR_DIR

pushd $MONITOR_DIR
    git clone https://github.com/Azure/Moneo  --branch $MONEO_VERSION
    
    chmod 777 Moneo

    pushd Moneo/linux_service
        ./configure_service.sh    
    popd
popd

# add an alias for Moneo
if ! grep -qxF "alias moneo='python3 /opt/azurehpc/tools/Moneo/moneo.py'" /etc/bashrc; then
    echo "alias moneo='python3 /opt/azurehpc/tools/Moneo/moneo.py'" >> /etc/bashrc
fi

$COMMON_DIR/write_component_version.sh "MONEO" ${MONEO_VERSION}
