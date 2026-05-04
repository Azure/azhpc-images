#!/bin/bash
# intended for only aarch64
set -ex

source ${UTILS_DIR}/utilities.sh

cuda_metadata=$(get_component_config "cuda")
CUDA_DRIVER_VERSION=$(jq -r '.driver.version' <<< $cuda_metadata)
CUDA_MAJOR_VERSION=$(echo $CUDA_DRIVER_VERSION | cut -d. -f1)

if [[ $DISTRIBUTION == "azurelinux3.0" ]]; then 
    NVSHMEM_CUDA_REPO="https://developer.download.nvidia.com/compute/cuda/repos/rhel9/sbsa"
    tdnf install -y --nogpgcheck \
        --repofrompath=cuda-rhel9-sbsa,$NVSHMEM_CUDA_REPO \
        libnvshmem3-cuda-$CUDA_MAJOR_VERSION libnvshmem3-devel-cuda-$CUDA_MAJOR_VERSION libnvshmem3-static-cuda-$CUDA_MAJOR_VERSION
    nvshmem_version=$(tdnf list installed | grep libnvshmem3-cuda-$CUDA_MAJOR_VERSION | awk '{print $2}')
elif [[ $DISTRIBUTION == *"ubuntu"* ]]; then
    apt install libnvshmem3-cuda-$CUDA_MAJOR_VERSION libnvshmem3-dev-cuda-$CUDA_MAJOR_VERSION
    nvshmem_version=$(apt list --installed | grep libnvshmem3-cuda-$CUDA_MAJOR_VERSION/ | cut -d' ' -f2)
fi


write_component_version "NVSHMEM" $nvshmem_version