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
if [[ -f ../cmake/InstallSamples.cmake ]]; then
	CMAKE_OPTIONS+=(-DCUDA_SAMPLES_INSTALL_DIR=/usr/local/cuda-${CUDA_DRIVER_VERSION}/samples)
fi
cmake "${CMAKE_OPTIONS[@]}" ..
make -j $(nproc)
if [[ -f ../cmake/InstallSamples.cmake ]]; then
	cmake --install .
else
	mv -vT ./Samples /usr/local/cuda-${CUDA_DRIVER_VERSION}/samples
fi
popd
