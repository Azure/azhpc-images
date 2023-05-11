#!/bin/bash


set -e

AZHC_VERSION=v0.2.1

pushd /opt/azurehpc/test/

git clone https://github.com/Azure/azurehpc-health-checks.git --branch $AZHC_VERSION

pushd azurehpc-health-checks

# install NHC
./install-nhc.sh

popd
popd

$COMMON_DIR/write_component_version.sh "MONEO" ${AZHC_VERSION}
