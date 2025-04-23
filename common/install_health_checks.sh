#!/bin/bash

set -ex

source ${COMMON_DIR}/utilities.sh

aznhc_metadata=$(get_component_config "aznhc")
AZHC_VERSION=$(jq -r '.version' <<< $aznhc_metadata)

DEST_TEST_DIR=/opt/azurehpc/test

mkdir -p $DEST_TEST_DIR

pushd $DEST_TEST_DIR

git clone https://github.com/Azure/azurehpc-health-checks.git --branch v$AZHC_VERSION

pushd azurehpc-health-checks

V100_CONF_UPD="$DEST_TEST_DIR/azurehpc-health-checks/conf/nd40rs_v2.conf"
if [[ -f "$V100_CONF_UPD" ]]; then
    echo "updating conf"
    sed -i 's/check_gpu_bw 10/check_gpu_bw 9.5/' "$V100_CONF_UPD"
    echo "bandwidth value changed from 10 to 9.5 for nd40rs_v2"
fi

# Pull down docker container from MCR
./dockerfile/pull-image-acr.sh cuda

popd
popd

$COMMON_DIR/write_component_version.sh "AZ_HEALTH_CHECKS" ${AZHC_VERSION}

kernel_version=$(rpm -q kernel | sed 's/kernel\-//g')
$COMMON_DIR/write_component_version.sh "KERNEL" ${kernel_version::-12}

os_version=$(rpm -qf /etc/os-release)
$COMMON_DIR/write_component_version.sh "OS" ${os_version::-12}
