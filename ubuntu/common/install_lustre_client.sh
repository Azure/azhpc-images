#!/bin/bash
set -ex

LUSTRE_VERSION=2.15.1-29-gbae0abe

source $UBUNTU_COMMON_DIR/setup_lustre_repo.sh

apt-get update
apt-get install -y amlfs-lustre-client-$lustre_version=$(uname -r)

$COMMON_DIR/write_component_version.sh "lustre" $lustre_version
