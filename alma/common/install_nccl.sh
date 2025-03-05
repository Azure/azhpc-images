#!/bin/bash
set -ex

source ${COMMON_DIR}/utilities.sh

# Set NCCL versions
nccl_metadata=$(get_component_config "nccl")
NCCL_VERSION=$(jq -r '.version' <<< $nccl_metadata)
NCCL_RDMA_SHARP_COMMIT=$(jq -r '.rdmasharpplugins.commit' <<< $nccl_metadata)

cuda_metadata=$(get_component_config "cuda")
CUDA_DRIVER_VERSION=$(jq -r '.driver.version' <<< $cuda_metadata)

TARBALL="v${NCCL_VERSION}.tar.gz"
NCCL_DOWNLOAD_URL=https://github.com/NVIDIA/nccl/archive/refs/tags/${TARBALL}

# Install NCCL
yum install -y rpm-build rpmdevtools

pushd /tmp
wget ${NCCL_DOWNLOAD_URL}
tar -xvf ${TARBALL}

pushd nccl-${NCCL_VERSION}
make -j src.build
make pkg.redhat.build
rpm -i ./build/pkg/rpm/x86_64/libnccl-${NCCL_VERSION}+cuda${CUDA_DRIVER_VERSION}.x86_64.rpm
rpm -i ./build/pkg/rpm/x86_64/libnccl-devel-${NCCL_VERSION}+cuda${CUDA_DRIVER_VERSION}.x86_64.rpm
rpm -i ./build/pkg/rpm/x86_64/libnccl-static-${NCCL_VERSION}+cuda${CUDA_DRIVER_VERSION}.x86_64.rpm
sed -i "$ s/$/ libnccl*/" /etc/dnf/dnf.conf
popd

# Install the nccl rdma sharp plugin
mkdir -p /usr/local/nccl-rdma-sharp-plugins
git clone https://github.com/Mellanox/nccl-rdma-sharp-plugins.git
pushd nccl-rdma-sharp-plugins
git checkout ${NCCL_RDMA_SHARP_COMMIT}
./autogen.sh
./configure --prefix=/usr/local/nccl-rdma-sharp-plugins --with-cuda=/usr/local/cuda
make
make install
popd
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
rm -rf /tmp/${TARBALL}
rm -rf /tmp/nccl-${NCCL_VERSION}
