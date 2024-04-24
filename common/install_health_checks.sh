#!/bin/bash

set -e


AZHC_VERSION=$(jq -r '.aznhc."'"$DISTRIBUTION"'".version' <<< $COMPONENT_VERSIONS)

DEST_TEST_DIR=/opt/azurehpc/test

mkdir -p $DEST_TEST_DIR

pushd $DEST_TEST_DIR

git clone https://github.com/Azure/azurehpc-health-checks.git --branch v$AZHC_VERSION

pushd azurehpc-health-checks

# Pull down docker container from MCR
./dockerfile/pull-image-acr.sh cuda

popd
popd

$COMMON_DIR/write_component_version.sh "AZ_HEALTH_CHECKS" ${AZHC_VERSION}
