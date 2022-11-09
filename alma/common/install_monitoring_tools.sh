#!/bin/bash

set -e

# Dependencies 
python3 -m pip install --upgrade pip
python3 -m pip install ansible

# Adding path to sudo user
sed -i 's/.*secure_path.*/Defaults    secure_path = \/usr\/local\/sbin:\/usr\/local\/bin:\/sbin:\/bin:\/usr\/sbin:\/usr\/bin\//' /etc/sudoers

MONITOR_DIR=/opt/azurehpc/tools

mkdir -p $MONITOR_DIR

pushd $MONITOR_DIR

git clone https://github.com/Azure/Moneo  --branch v0.2.2

popd
