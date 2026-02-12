#!/bin/bash
# intended for only gb200
set -ex

source ${UTILS_DIR}/utilities.sh

cuda_metadata=$(get_component_config "cuda")
CUDA_DRIVER_VERSION=$(jq -r '.driver.version' <<< $cuda_metadata)
CUDA_MAJOR_VERSION=$(echo $CUDA_DRIVER_VERSION | cut -d. -f1)

if [[ $DISTRIBUTION == "azurelinux3.0" ]]; then 
    path_var="$TOP_DIR/prebuilt"
    tdnf install -y $path_var/libnvshmem3-cuda-$CUDA_MAJOR_VERSION-*.rpm
    tdnf install -y $path_var/libnvshmem3-devel-cuda-$CUDA_MAJOR_VERSION-*.rpm
    tdnf install -y $path_var/libnvshmem3-static-cuda-$CUDA_MAJOR_VERSION-*.rpm
    nvshmem_version=$(tdnf list installed | grep libnvshmem3-cuda-$CUDA_MAJOR_VERSION/ | cut -d' ' -f2)
elif [[ $DISTRIBUTION == *"ubuntu"* ]]; then
    apt install libnvshmem3-cuda-$CUDA_MAJOR_VERSION libnvshmem3-dev-cuda-$CUDA_MAJOR_VERSION
    nvshmem_version=$(apt list --installed | grep libnvshmem3-cuda-$CUDA_MAJOR_VERSION/ | cut -d' ' -f2)
fi


write_component_version "NVSHMEM" $nvshmem_version