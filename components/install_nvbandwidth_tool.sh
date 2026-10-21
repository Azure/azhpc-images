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
    dnf -y install boost-devel
elif [[ $DISTRIBUTION == "azurelinux3.0" && $ARCHITECTURE == "aarch64" ]]; then
    # Download dependencies
    dnf install -y boost-devel boost-program-options
    dnf install -y cmake
fi

# Download the nvbandwidth tool
nvbandwidth_metadata=$(get_component_config "nvbandwidth")
NVBANDWIDTH_VERSION=$(jq -r '.version' <<< $nvbandwidth_metadata)
NVBANDWIDTH_DOWNLOAD_URL=$(jq -r '.url' <<< $nvbandwidth_metadata)
NVBANDWIDTH_COMMIT=$(jq -r '.commit // empty' <<< $nvbandwidth_metadata)
NVBANDWIDTH_REF=$(jq -r '.ref // .branch // empty' <<< $nvbandwidth_metadata)
NVBANDWIDTH_REF=${NVBANDWIDTH_REF:-v${NVBANDWIDTH_VERSION}}

# Clone the repository and checkout the configured ref.
git clone --branch ${NVBANDWIDTH_REF} ${NVBANDWIDTH_DOWNLOAD_URL}

# Install the nvbandwidth tool
pushd nvbandwidth
git checkout ${NVBANDWIDTH_COMMIT}
write_repo_source_info "NVBANDWIDTH" . \
    --commit "${NVBANDWIDTH_COMMIT}" \
    --ref "${NVBANDWIDTH_REF}"
source /etc/profile.d/modules.sh
module load mpi/hpcx
cmake -DCMAKE_CUDA_COMPILER=/usr/local/cuda/bin/nvcc -DMULTINODE=1 .
make
mv ./nvbandwidth $dest_dir
popd

rm -rf ./nvbandwidth
write_component_version "NVBANDWIDTH" ${NVBANDWIDTH_VERSION}
