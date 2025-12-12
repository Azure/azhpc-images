#!/bin/bash

set -ex
source ${UTILS_DIR}/utilities.sh

dest_dir=/opt/nvidia/nvloom
mkdir -p $dest_dir

source /etc/profile.d/modules.sh
module load mpi/hpcx

# Download dependencies
apt install -y build-essential
apt install -y libboost-program-options-dev
apt install -y cmake

# Clone the repository and checkout the v1.2.0 tag
NVLOOM_DOWNLOAD_URL="https://github.com/NVIDIA/nvloom.git"
NVLOOM_VERSION="1.2.0"
git clone $NVLOOM_DOWNLOAD_URL --branch v$NVLOOM_VERSION
pushd nvloom
cmake -DCMAKE_CUDA_COMPILER=/usr/local/cuda/bin/nvcc -DCMAKE_CUDA_ARCHITECTURES="100" .
make -j $(nproc)
mv nvloom_cli $dest_dir
popd

module unload mpi/hpcx

rm -rf ./nvloom

write_component_version "NVLOOM" ${NVLOOM_VERSION}