#!/bin/bash
set -ex

# Set the azhc version
azhc_version=$(jq -r '.azhc."'"$DISTRIBUTION"'".version' <<< $COMPONENT_VERSIONS)

dest_test_dir=$HPC_ENV/test
azhc_dir=$HPC_ENV/test/azurehpc-health-checks

mkdir -p $dest_test_dir

pushd $dest_test_dir
wget https://github.com/Azure/azurehpc-health-checks/archive/refs/tags/v$azhc_version.tar.gz
tar -xvf ./v$azhc_version.tar.gz

pushd azurehpc-health-checks-$azhc_version
# install NHC
./install-nhc.sh
popd

rm -rf ./v$azhc_version.tar.gz
popd

$COMMON_DIR/write_component_version.sh "az_health_checks" $azhc_version
