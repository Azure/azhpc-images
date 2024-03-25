#!/bin/bash
set -ex

# Set Lustre version
LUSTRE_VERSION=$(jq -r '.lustre."'"$DISTRIBUTION"'".version' <<< $COMPONENT_VERSIONS)

source $UBUNTU_COMMON_DIR/setup_lustre_repo.sh

apt-get update
apt-get install -y amlfs-lustre-client-${LUSTRE_VERSION}=$(uname -r)

$COMMON_DIR/write_component_version.sh "LUSTRE" ${LUSTRE_VERSION}
