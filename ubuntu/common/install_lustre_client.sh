#!/bin/bash
set -ex

source ${COMMON_DIR}/utilities.sh

# Set Lustre version
lustre_metadata=$(get_component_config "lustre")
LUSTRE_VERSION=$(jq -r '.version' <<< $lustre_metadata)

source $UBUNTU_COMMON_DIR/setup_lustre_repo.sh

apt-get update
apt-get install -y amlfs-lustre-client-${LUSTRE_VERSION}=$(uname -r)
apt-mark hold amlfs-lustre-client-${LUSTRE_VERSION}

$COMMON_DIR/write_component_version.sh "LUSTRE" ${LUSTRE_VERSION}
