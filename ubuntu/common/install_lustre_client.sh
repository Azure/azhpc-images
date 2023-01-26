#!/bin/bash
set -ex

LUSTRE_VERSION=2.15.1-24-gbaa21ca

source $UBUNTU_COMMON_DIR/setup_lustre_repo.sh

apt-get update
apt-get install -y amlfs-lustre-client-${LUSTRE_VERSION}=$(uname -r)

$COMMON_DIR/write_component_version.sh "LUSTRE" ${LUSTRE_VERSION}
