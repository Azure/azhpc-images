#!/bin/bash
set -ex

# grab latest release version of AZHC
repo=Azure/azurehpc-health-checks
azhc_version=$(curl -s "https://api.github.com/repos/$repo/releases/latest" | jq -r '.tag_name')


dest_test_dir=$HPC_ENV/test
azhc_dir=$HPC_ENV/test/azurehpc-health-checks

mkdir -p $dest_test_dir

pushd $dest_test_dir

git clone https://github.com/Azure/azurehpc-health-checks.git --branch $azhc_version

pushd azurehpc-health-checks

# install NHC
./install-nhc.sh

popd
popd

$COMMON_DIR/write_component_version.sh "az_health_checks" $azhc_version
