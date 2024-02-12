#!/bin/bash


set -e

# grab latest release version
repo=Azure/azurehpc-health-checks
release_version=$(curl -s "https://api.github.com/repos/$repo/releases/latest" | jq -r '.tag_name')

AZHC_VERSION=$release_version

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
