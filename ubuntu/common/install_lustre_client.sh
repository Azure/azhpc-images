#!/bin/bash
set -ex

# Set Lustre version
lustre_version=$(jq -r '.lustre."'"$DISTRIBUTION"'".version' <<< $COMPONENT_VERSIONS)

source $UBUNTU_COMMON_DIR/setup_lustre_repo.sh

apt-get update
apt-get install -y amlfs-lustre-client-$lustre_version=$(uname -r)

$COMMON_DIR/write_component_version.sh "lustre" $lustre_version
