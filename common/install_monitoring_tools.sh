#!/bin/bash

set -ex

# grab latest release version of Moneo
repo=Azure/Moneo
moneo_version=$(curl -s "https://api.github.com/repos/$repo/releases/latest" | jq -r '.tag_name')


monitor_dir=$HPC_ENV/tools

mkdir -p $monitor_dir

pushd $monitor_dir

    git clone https://github.com/Azure/Moneo  --branch $moneo_version

    chmod 777 Moneo

    pushd Moneo/linux_service
        ./configure_service.sh      
    popd
popd

# add an alias for Moneo
if ! grep -qxF "alias moneo='python3 $HPC_ENV/tools/Moneo/moneo.py'" /etc/profile; then
    echo "alias moneo='python3 $HPC_ENV/tools/Moneo/moneo.py'" >> /etc/profile
fi

$COMMON_DIR/write_component_version.sh "moneo" $moneo_version
