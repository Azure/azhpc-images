#!/bin/bash

set -e

MONEO_VERSION=v0.2.3

# Dependencies 
python3 -m pip install --upgrade pip
python3 -m pip install ansible

# Adding path to sudo user
sed -i 's/.*secure_path.*/Defaults    secure_path = \/usr\/local\/sbin:\/usr\/local\/bin:\/sbin:\/bin:\/usr\/sbin:\/usr\/bin\//' /etc/sudoers

MONITOR_DIR=/opt/azurehpc/tools

mkdir -p $MONITOR_DIR

pushd $MONITOR_DIR

git clone https://github.com/Azure/Moneo  --branch $MONEO_VERSION

chmod 777 Moneo

popd

$COMMON_DIR/write_component_version.sh "MONEO" ${MONEO_VERSION}
