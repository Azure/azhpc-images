#!/bin/bash

set -ex

source ${COMMON_DIR}/utilities.sh

aznhc_metadata=$(get_component_config "aznhc")
AZHC_VERSION=$(jq -r '.version' <<< $aznhc_metadata)
AZHC_SHA=$(jq -r '.sha256' <<< $aznhc_metadata)

hpcx_metadata=$(get_component_config "hpcx")
HPCX_DOWNLOAD_URL=$(jq -r '.url' <<< $hpcx_metadata)
HPCX_FOLDER=$(basename $HPCX_DOWNLOAD_URL .tbz)

DEST_TEST_DIR=/opt/azurehpc/test
GPU_PLAT=$1

TARBALL="v${AZHC_VERSION}.tar.gz"
AZHC_DOWNLOAD_URL=https://github.com/Azure/azurehpc-health-checks/archive/refs/tags/${TARBALL}
$COMMON_DIR/download_and_verify.sh ${AZHC_DOWNLOAD_URL} ${AZHC_SHA} $DEST_TEST_DIR

pushd $DEST_TEST_DIR
if [ "${GPU_PLAT}" = "NVIDIA" ]; then
   mkdir azurehpc-health-checks && tar -xvf $TARBALL --strip-components=1 -C azurehpc-health-checks  
   pushd azurehpc-health-checks
   chmod +x ./dockerfile/pull-image-mcr.sh
   # Pull down docker container from MCR
   ./dockerfile/pull-image-mcr.sh cuda
   popd
else
   git clone https://github.com/Azure/azurehpc-health-checks.git
   pushd azurehpc-health-checks
   # Pull down docker container from MCR
   ./dockerfile/pull-image-mcr.sh rocm
   popd
fi
popd

$COMMON_DIR/write_component_version.sh "AZ_HEALTH_CHECKS" ${AZHC_VERSION}
