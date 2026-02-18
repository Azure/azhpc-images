set -ex

source ${UTILS_DIR}/utilities.sh

dest_dir=/opt/nvidia/nvbandwidth
mkdir -p $dest_dir

# Download dependencies
if [[ $DISTRIBUTION == *"ubuntu"* ]]; then
    apt install -y libboost-program-options-dev
elif [[ $DISTRIBUTION == almalinux* ]]; then
    dnf -y install boost-devel
elif [[ $DISTRIBUTION == "azurelinux3.0" && $ARCHITECTURE != "aarch64" ]]; then
    tdnf -y install boost-devel
elif [[ $DISTRIBUTION == "azurelinux3.0" && $ARCHITECTURE == "aarch64" ]]; then
    # Download dependencies
    tdnf install -y build-essential
    tdnf install -y boost-devel boost-program-options
    tdnf install -y cmake

    # Download the nvbandwidth tool
    NVBANDWIDTH_VERSION=0.8
    NVBANDWIDTH_DOWNLOAD_URL=https://github.com/NVIDIA/nvbandwidth/archive/refs/tags/v0.8.tar.gz

    wget $NVBANDWIDTH_DOWNLOAD_URL
    tar -xvf $(basename $NVBANDWIDTH_DOWNLOAD_URL)
    rm -rf ./*.tar.gz

    # Install the nvbandwidth tool
    pushd nvbandwidth-$NVBANDWIDTH_VERSION
    # patch to skip boost static libs on Azure Linux
    sed -i 's/ID=.*fedora/ID=.*fedora|azurelinux/' CMakeLists.txt
    cmake -DCMAKE_CUDA_COMPILER=/usr/local/cuda/bin/nvcc -DCMAKE_CUDA_ARCHITECTURES="100" .
    make
    mv ./nvbandwidth $dest_dir
    popd

    rm -rf ./nvbandwidth-$NVBANDWIDTH_VERSION
    write_component_version "NVBANDWIDTH" ${NVBANDWIDTH_VERSION}
    exit 0
fi

# Download the nvbandwidth tool
nvbandwidth_metadata=$(get_component_config "nvbandwidth")
NVBANDWIDTH_VERSION=$(jq -r '.version' <<< $nvbandwidth_metadata)
NVBANDWIDTH_DOWNLOAD_URL=$(jq -r '.url' <<< $nvbandwidth_metadata)

# Clone the repository and checkout the v0.8 tag
git clone --branch v${NVBANDWIDTH_VERSION} ${NVBANDWIDTH_DOWNLOAD_URL}

# Install the nvbandwidth tool
pushd nvbandwidth
cmake -DCMAKE_CUDA_COMPILER=/usr/local/cuda/bin/nvcc -DCMAKE_CUDA_ARCHITECTURES="100" .
make
mv ./nvbandwidth $dest_dir
popd

rm -rf ./nvbandwidth
write_component_version "NVBANDWIDTH" ${NVBANDWIDTH_VERSION}