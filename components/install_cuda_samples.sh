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
cmake -DCMAKE_CUDA_COMPILER=/usr/local/cuda/bin/nvcc ..
make -j $(nproc)

CUDA_DIR=$(readlink -f /usr/local/cuda)

# Locate the built samples tree. The layout changed across CUDA releases:
#   - CUDA 13.4 (CMake reorg): sources under cpp/, Linux executables built into
#     build/cpp/<category>/<name>/ ; there is no top-level Samples/ (the repo's
#     bin/ holds only Windows DLLs).
SAMPLES_SRC=""
for cand in ./Samples ./cpp; do
    if [[ -d "${cand}" ]]; then
        SAMPLES_SRC="${cand}"
        break
    fi
done
if [[ -z "${SAMPLES_SRC}" ]]; then
    echo "ERROR: could not locate built CUDA samples (checked ./cpp and ./Samples) under $(pwd)" >&2
    exit 1
fi

mkdir -p "${CUDA_DIR}/samples"
mv -vT "${SAMPLES_SRC}" "${CUDA_DIR}/samples"
popd