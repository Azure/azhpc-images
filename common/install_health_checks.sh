#!/bin/bash

set -ex

source ${COMMON_DIR}/utilities.sh

aznhc_metadata=$(get_component_config "aznhc")
AZHC_VERSION=$(jq -r '.version' <<< $aznhc_metadata)

DEST_TEST_DIR=/opt/azurehpc/test
GPU_PLAT=$1

mkdir -p $DEST_TEST_DIR

pushd $DEST_TEST_DIR

if [ "${GPU_PLAT}" = "NVIDIA" ]; then
   git clone https://github.com/Azure/azurehpc-health-checks.git --branch v$AZHC_VERSION

   pushd azurehpc-health-checks

   # Pull CUDA Docker image from MCR
   ./dockerfile/pull-image-mcr.sh cuda
   popd
else
   git clone https://github.com/Azure/azurehpc-health-checks.git --branch v$AZHC_VERSION
   
   pushd azurehpc-health-checks
   
   # Pull ROCm Docker image from MCR
   ./dockerfile/pull-image-mcr.sh rocm
   popd
fi

popd

$COMMON_DIR/write_component_version.sh "AZ_HEALTH_CHECKS" ${AZHC_VERSION}
