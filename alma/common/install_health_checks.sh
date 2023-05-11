#!/bin/bash


set -e

AZHC_VERSION=v0.2.0
AOCC_VERSION=4.0.0-1

# install dependency
wget https://download.amd.com/developer/eula/aocc-compiler/aocc-compiler-${AOCC_VERSION}.x86_64.rpm
dnf install -y ./aocc-compiler-${AOCC_VERSION}.x86_64.rpm

rm ./aocc-compiler-${AOCC_VERSION}.x86_64.rpm

pushd /opt/azurehpc/test/git status

git clone https://github.com/Azure/azurehpc-health-checks.git --branch $AZHC_VERSION

pushd azurehpc-health-checks

# install NHC
./install-nhc.sh

popd

$COMMON_DIR/write_component_version.sh "AOCC" ${AOCC_VERSION}
$COMMON_DIR/write_component_version.sh "MONEO" ${AZHC_VERSION}
