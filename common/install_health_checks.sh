#!/bin/bash
set -ex

# Set the azhc version
azhc_version=$(jq -r '.azhc."'"$DISTRIBUTION"'".version' <<< $COMPONENT_VERSIONS)

dest_test_dir=$HPC_ENV/test
azhc_dir=$HPC_ENV/test/azurehpc-health-checks

mkdir -p $dest_test_dir

pushd $dest_test_dir

git clone https://github.com/Azure/azurehpc-health-checks.git --branch v$azhc_version

pushd azurehpc-health-checks

# install NHC
./install-nhc.sh

popd
popd

$COMMON_DIR/write_component_version.sh "az_health_checks" $azhc_version
