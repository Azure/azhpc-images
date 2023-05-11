#!/bin/bash


set -e

AZHC_VERSION=v0.2.1
AOCC_VERSION=4.0.0_1

# install dependency
wget https://download.amd.com/developer/eula/aocc-compiler/aocc-compiler-${AOCC_VERSION}_amd64.deb
apt install -y ./aocc-compiler-${AOCC_VERSION}_amd64.deb

rm aocc-compiler-${AOCC_VERSION}_amd64.deb 

pushd /opt/azurehpc/test/

git clone https://github.com/Azure/azurehpc-health-checks.git --branch $AZHC_VERSION

pushd azurehpc-health-checks

# install NHC
./install-nhc.sh

popd
popd

$COMMON_DIR/write_component_version.sh "AOCC" ${AOCC_VERSION}
$COMMON_DIR/write_component_version.sh "MONEO" ${AZHC_VERSION}
