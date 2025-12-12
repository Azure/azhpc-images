set -ex

source ${UTILS_DIR}/utilities.sh

cuda_metadata=$(get_component_config "cuda")
CUDA_DRIVER_VERSION=$(jq -r '.driver.version' <<< $cuda_metadata)
CUDA_MAJOR_VERSION=$(echo $CUDA_DRIVER_VERSION | cut -d. -f1)

apt install libnvshmem3-cuda-$CUDA_MAJOR_VERSION libnvshmem3-dev-cuda-$CUDA_MAJOR_VERSION
nvshmem_version=$(apt list --installed | grep libnvshmem3-cuda-$CUDA_MAJOR_VERSION/ | cut -d' ' -f2)

write_component_version "NVSHMEM" $nvshmem_version