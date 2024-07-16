#!/bin/bash
set -ex

# Set NCCL versions
nccl_metadata=$(jq -r '.nccl."'"$DISTRIBUTION"'"' <<< $COMPONENT_VERSIONS)
NCCL_VERSION=$(jq -r '.version' <<< $nccl_metadata)
NCCL_SHA256=$(jq -r '.sha256' <<< $nccl_metadata)
NCCL_RDMA_SHARP_COMMIT=$(jq -r '.rdmasharpplugins.commit' <<< $nccl_metadata)
CUDA_DRIVER_VERSION=$(jq -r '.cuda."'"$DISTRIBUTION"'".driver.version' <<< $COMPONENT_VERSIONS)

CUDA_VERSION="${CUDA_DRIVER_VERSION//-/.}"
TARBALL="v${NCCL_VERSION}.tar.gz"
NCCL_DOWNLOAD_URL=https://github.com/NVIDIA/nccl/archive/refs/tags/${TARBALL}

# Install NCCL
apt install -y build-essential devscripts debhelper fakeroot

$COMMON_DIR/download_and_verify.sh ${NCCL_DOWNLOAD_URL} ${NCCL_SHA256}
tar -xvf ${TARBALL}

pushd nccl-${NCCL_VERSION}
make -j src.build
make pkg.debian.build
pushd build/pkg/deb/
dpkg -i libnccl2_${NCCL_VERSION}+cuda${CUDA_VERSION}_amd64.deb
apt-mark hold libnccl2
dpkg -i libnccl-dev_${NCCL_VERSION}+cuda${CUDA_VERSION}_amd64.deb
apt-mark hold libnccl-dev
popd
popd

# Install the nccl rdma sharp plugin
mkdir -p /usr/local/nccl-rdma-sharp-plugins
apt install -y zlib1g-dev
git clone https://github.com/Mellanox/nccl-rdma-sharp-plugins.git
pushd nccl-rdma-sharp-plugins
git checkout ${NCCL_RDMA_SHARP_COMMIT}
./autogen.sh
./configure --prefix=/usr/local/nccl-rdma-sharp-plugins --with-cuda=/usr/local/cuda
make
make install
popd

# Build the nccl tests
source /etc/profile.d/modules.sh
module load mpi/hpcx
git clone https://github.com/NVIDIA/nccl-tests.git
pushd nccl-tests
make MPI=1 MPI_HOME=${HPCX_MPI_DIR} CUDA_HOME=/usr/local/cuda
popd
mv nccl-tests /opt/.
module unload mpi/hpcx

$COMMON_DIR/write_component_version.sh "NCCL" ${NCCL_VERSION}

# Remove installation files
rm -rf ${TARBALL}
rm -rf nccl-${NCCL_VERSION}
