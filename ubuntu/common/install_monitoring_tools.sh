#!/bin/bash

set -e

# Set moneo metadata
moneo_version=$(jq -r '.moneo."'"$DISTRIBUTION"'".version' <<< $COMPONENT_VERSIONS)

# Dependencies 
python3 -m pip install --upgrade pip

monitor_dir=$HPC_ENV/tools

mkdir -p $monitor_dir

pushd $monitor_dir

    git clone https://github.com/Azure/Moneo  --branch $moneo_version

    chmod 777 Moneo

    pushd Moneo/linux_service
        ./configure_service.sh $monitor_dir/Moneo       
    popd
popd

# add an slias for Moneo
if ! grep -qxF "alias moneo='python3 $HPC_ENV/tools/Moneo/moneo.py'" /etc/bash.bashrc; then
    echo "alias moneo='python3 $HPC_ENV/tools/Moneo/moneo.py'" >> /etc/bash.bashrc
fi

$COMMON_DIR/write_component_version.sh "moneo" $moneo_version
