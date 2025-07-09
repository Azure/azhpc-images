#!/bin/bash
set -ex

source ${UTILS_DIR}/utilities.sh

# Set Intel® oneAPI Math Kernel Library info
intel_one_mkl_metadata=$(get_component_config "intel_one_mkl")
INTEL_ONE_MKL_VERSION=$(jq -r '.version' <<< $intel_one_mkl_metadata)
INTEL_ONE_MKL_SHA256=$(jq -r '.sha256' <<< $intel_one_mkl_metadata)
INTEL_ONE_MKL_DOWNLOAD_URL=$(jq -r '.url' <<< $intel_one_mkl_metadata)
INTEL_ONE_MKL_OFFLINE_INSTALLER=$(basename $INTEL_ONE_MKL_DOWNLOAD_URL)

# Install Intel® oneAPI Math Kernel Library
write_component_version "INTEL_ONE_MKL" ${INTEL_ONE_MKL_VERSION}
download_and_verify ${INTEL_ONE_MKL_DOWNLOAD_URL} ${INTEL_ONE_MKL_SHA256}
sh ./${INTEL_ONE_MKL_OFFLINE_INSTALLER} -s -a -s --eula accept

rm -f ${INTEL_ONE_MKL_OFFLINE_INSTALLER}

write_component_version "INTEL_ONE_MKL" ${INTEL_ONE_MKL_VERSION}
