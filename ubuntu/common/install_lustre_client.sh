#!/bin/bash
set -ex

lustre_version=2.15.1-24-gbaa21ca

source $UBUNTU_COMMON_DIR/setup_lustre_repo.sh

apt-get update
apt-get install -y amlfs-lustre-client-$lustre_version=$(uname -r)

$COMMON_DIR/write_component_version.sh "lustre" $lustre_version
