#!/bin/bash
set -ex

source ${UTILS_DIR}/utilities.sh

# Read CUDA config from versions.json
cuda_metadata=$(get_component_config "cuda")
CUDA_DRIVER_VERSION=$(jq -r '.driver.version' <<< $cuda_metadata)
CUDA_SAMPLES_VERSION=$(jq -r '.samples.version' <<< $cuda_metadata)
CUDA_SAMPLES_SHA256=$(jq -r '.samples.sha256' <<< $cuda_metadata)

# Download and build CUDA samples
TARBALL="v${CUDA_SAMPLES_VERSION}.tar.gz"
CUDA_SAMPLES_DOWNLOAD_URL=https://github.com/NVIDIA/cuda-samples/archive/refs/tags/${TARBALL}
download_and_verify ${CUDA_SAMPLES_DOWNLOAD_URL} ${CUDA_SAMPLES_SHA256}
tar -xvf ${TARBALL}
pushd ./cuda-samples-${CUDA_SAMPLES_VERSION}
mkdir build && cd build
CMAKE_OPTIONS=(-DCMAKE_CUDA_COMPILER=/usr/local/cuda/bin/nvcc)
if [[ "$DISTRIBUTION" == "ubuntu26.04" && "$CUDA_DRIVER_VERSION" == 12.* ]]; then
	# CUDA 12.9 is the final toolkit with Volta code generation, but it rejects GCC 15.
	apt-get install -y gcc-14 g++-14
	CMAKE_OPTIONS+=(
		-DCMAKE_C_COMPILER=/usr/bin/gcc-14
		-DCMAKE_CXX_COMPILER=/usr/bin/g++-14
		-DCMAKE_CUDA_HOST_COMPILER=/usr/bin/g++-14
	)
fi
cmake "${CMAKE_OPTIONS[@]}" ..
make -j $(nproc)
mv -vT ./Samples /usr/local/cuda-${CUDA_DRIVER_VERSION}/samples
popd
