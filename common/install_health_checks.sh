#!/bin/bash

set -ex

source ${COMMON_DIR}/utilities.sh

aznhc_metadata=$(get_component_config "aznhc")
AZHC_VERSION=$(jq -r '.version' <<< $aznhc_metadata)
AZHC_SHA=$(jq -r '.sha256' <<< $aznhc_metadata)

DEST_TEST_DIR=/opt/azurehpc/test
GPU_PLAT=$1

mkdir -p $DEST_TEST_DIR

pushd $DEST_TEST_DIR

if [ "${GPU_PLAT}" = "NVIDIA" ]; then
    git clone https://github.com/Azure/azurehpc-health-checks.git --branch v$AZHC_VERSION

    pushd azurehpc-health-checks

    V100_CONF_FILE="$DEST_TEST_DIR/azurehpc-health-checks/conf/nd40rs_v2.conf"
    if [[ -f "$V100_CONF_FILE" ]]; then
        echo "updating conf"
        sed -i 's/check_gpu_bw 10/check_gpu_bw 9.5/' "$V100_CONF_FILE"
        echo "bandwidth value changed from 10 to 9.5 for nd40rs_v2"
    fi

    # Pull down docker container from MCR
    ./dockerfile/pull-image-acr.sh cuda

    popd
    
else
   TARBALL="v${AZHC_VERSION}.tar.gz"
   AZHC_DOWNLOAD_URL=https://github.com/Azure/azurehpc-health-checks/archive/refs/tags/${TARBALL}
   $COMMON_DIR/download_and_verify.sh ${AZHC_DOWNLOAD_URL} ${AZHC_SHA} $DEST_TEST_DIR
   
   mkdir azurehpc-health-checks && tar -xvf $TARBALL --strip-components=1 -C azurehpc-health-checks  
   pushd azurehpc-health-checks
   
   chmod +x ./dockerfile/pull-image-mcr.sh
   # Build docker image for AMD while waiting to be published on MCR
   ./dockerfile/build_image.sh rocm

   popd
fi
popd

$COMMON_DIR/write_component_version.sh "AZ_HEALTH_CHECKS" ${AZHC_VERSION}

kernel_version=$(rpm -q kernel | sed 's/kernel\-//g')
$COMMON_DIR/write_component_version.sh "KERNEL" ${kernel_version::-12}

os_version=$(rpm -qf /etc/os-release)
$COMMON_DIR/write_component_version.sh "OS" ${os_version::-12}
