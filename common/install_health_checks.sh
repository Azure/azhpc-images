#!/bin/bash


set -e

AZHC_VERSION=v0.2.4

DEST_TEST_DIR=/opt/azurehpc/test
AZHC_DIR=/opt/azurehpc/test/azurehpc-health-checks

mkdir -p $DEST_TEST_DIR

pushd $DEST_TEST_DIR

git clone https://github.com/Azure/azurehpc-health-checks.git --branch $AZHC_VERSION

pushd azurehpc-health-checks

# install NHC
./install-nhc.sh

popd
popd

$COMMON_DIR/write_component_version.sh "AZ_HEALTH_CHECKS" ${AZHC_VERSION}
