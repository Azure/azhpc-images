#!/bin/bash

set -ex

source ${COMMON_DIR}/utilities.sh

aznhc_metadata=$(get_component_config "aznhc")
AZHC_VERSION=$(jq -r '.version' <<< $aznhc_metadata)
AZHC_SHA=$(jq -r '.sha256' <<< $aznhc_metadata)

DEST_TEST_DIR=/opt/azurehpc/test
GHR_SOURCE_DIR=$(realpath $COMMON_DIR)
GPU_PLAT=$1

TARBALL="v${AZHC_VERSION}.tar.gz"
AZHC_DOWNLOAD_URL=https://github.com/Azure/azurehpc-health-checks/archive/refs/tags/${TARBALL}
$COMMON_DIR/download_and_verify.sh ${AZHC_DOWNLOAD_URL} ${AZHC_SHA} $DEST_TEST_DIR

pushd $DEST_TEST_DIR
mkdir azurehpc-health-checks && tar -xvf $TARBALL --strip-components=1 -C azurehpc-health-checks  
pushd azurehpc-health-checks
rm ./triggerGHR/triggerGHR.sh
cp ${GHR_SOURCE_DIR}/trigger_aznhc_GHR.sh ./triggerGHR/triggerGHR.sh
dos2unix ./triggerGHR/config/*
chmod +x ./triggerGHR/triggerGHR.sh
chmod +x ./dockerfile/pull-image-mcr.sh
# Pull down docker container from MCR
if [ "${GPU_PLAT}" = "AMD" ]; then
   ./dockerfile/pull-image-mcr.sh rocm
else
   ./dockerfile/pull-image-mcr.sh cuda
fi
popd
popd

$COMMON_DIR/write_component_version.sh "AZ_HEALTH_CHECKS" ${AZHC_VERSION}
