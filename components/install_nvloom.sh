#!/bin/bash
# intended for only gb200

set -ex
source ${UTILS_DIR}/utilities.sh

dest_dir=/opt/nvidia/nvloom
mkdir -p $dest_dir

source /etc/profile.d/modules.sh
module load mpi/hpcx

nvloom_metadata=$(get_component_config "nvloom")
NVLOOM_VERSION=$(jq -r '.version' <<< $nvloom_metadata)
NVLOOM_DOWNLOAD_URL=$(jq -r '.url' <<< $nvloom_metadata)

if [[ $DISTRIBUTION == "azurelinux3.0" ]]; then
    # Download dependencies
    tdnf install -y build-essential
    tdnf install -y boost-devel boost-program-options
    tdnf install -y cmake

    git clone $NVLOOM_DOWNLOAD_URL --branch v$NVLOOM_VERSION
    pushd nvloom
    git apply /home/hpcuser/azhpc-images/distros/azurelinux3.0/azurelinux_nvloom.patch
    cmake -DCMAKE_CUDA_COMPILER=/usr/local/cuda/bin/nvcc -DCMAKE_CUDA_ARCHITECTURES="100" .
    make -j $(nproc)
    mv nvloom_cli $dest_dir
    popd
elif [[ $DISTRIBUTION == *"ubuntu"* ]]; then
    # Download dependencies
    apt install -y build-essential
    apt install -y libboost-program-options-dev
    apt install -y cmake

    git clone $NVLOOM_DOWNLOAD_URL --branch v$NVLOOM_VERSION
    pushd nvloom
    cmake -DCMAKE_CUDA_COMPILER=/usr/local/cuda/bin/nvcc -DCMAKE_CUDA_ARCHITECTURES="100" .
    make -j $(nproc)
    mv nvloom_cli $dest_dir
    popd
fi


module unload mpi/hpcx

rm -rf ./nvloom
 
write_component_version "NVLOOM" ${NVLOOM_VERSION}