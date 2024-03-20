#!/bin/bash
set -ex

# Set Intel® oneAPI Math Kernel Library info
intel_one_mkl_metadata=$(jq -r '.intel_one_mkl."'"$DISTRIBUTION"'"' <<< $COMPONENT_VERSIONS)
INTEL_ONE_MKL_VERSION=$(jq -r '.version' <<< $intel_one_mkl_metadata)
INTEL_ONE_MKL_SHA256=$(jq -r '.sha256' <<< $impi_metadata)
INTEL_ONE_MKL_DOWNLOAD_URL=$(jq -r '.url' <<< $impi_metadata)
INTEL_ONE_MKL_OFFLINE_INSTALLER=$(basename $IMPI_DOWNLOAD_URL)

# Intel® oneAPI Math Kernel Library
$COMMON_DIR/write_component_version.sh "INTEL_ONE_MKL" ${INTEL_ONE_MKL_VERSION}
$COMMON_DIR/download_and_verify.sh ${INTEL_ONE_MKL_DOWNLOAD_URL} ${INTEL_ONE_MKL_SHA256}
sh ./${INTEL_ONE_MKL_OFFLINE_INSTALLER} -s -a -s --eula accept
