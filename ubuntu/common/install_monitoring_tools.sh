#!/bin/bash

set -e

# Set moneo metadata
moneo_version=$(jq -r '.moneo."'"$DISTRIBUTION"'".version' $TOP_DIR/requirements.json)

# Dependencies 
python3 -m pip install --upgrade pip
python3 -m pip install ansible

monitor_path=$HPC_ENV/tools
mkdir -p $monitor_path

pushd $monitor_path
git clone https://github.com/Azure/Moneo  --branch $moneo_version
chmod 777 Moneo
popd

$COMMON_DIR/write_component_version.sh "moneo" $moneo_version
