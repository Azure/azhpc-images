#!/bin/bash
set -ex

# Install NCCL
# Optimized primitives for inter-GPU communication.
NCCL_VERSION="2.15.1-1" # for cuda-11.8
#NCCL_VERSION="2.16.51-1" # for cuda-11.8


zypper install -y -l rpm-build rpmdevtools git

TARBALL="v${NCCL_VERSION}.tar.gz"
NCCL_DOWNLOAD_URL=https://github.com/NVIDIA/nccl/archive/refs/tags/${TARBALL}
pushd /tmp
wget ${NCCL_DOWNLOAD_URL}
tar -xvf ${TARBALL}

pushd nccl-${NCCL_VERSION}
make -j src.build
make pkg.redhat.build
rpm -i ./build/pkg/rpm/x86_64/libnccl-${NCCL_VERSION}+cuda11.8.x86_64.rpm
rpm -i ./build/pkg/rpm/x86_64/libnccl-devel-${NCCL_VERSION}+cuda11.8.x86_64.rpm
rpm -i ./build/pkg/rpm/x86_64/libnccl-static-${NCCL_VERSION}+cuda11.8.x86_64.rpm
popd

# Install the nccl rdma sharp plugin
# we need the packages: autoconf automake libtool rdma-core-devel
mkdir -p /usr/local/nccl-rdma-sharp-plugins
git clone https://github.com/Mellanox/nccl-rdma-sharp-plugins.git
pushd nccl-rdma-sharp-plugins
./autogen.sh
./configure --prefix=/usr/local/nccl-rdma-sharp-plugins --with-cuda=/usr/local/cuda
make
make install
popd
popd

# Build the nccl tests
source /usr/share/lmod/lmod/init/bash
module load mpi/hpcx
git clone https://github.com/NVIDIA/nccl-tests.git
pushd nccl-tests
make MPI=1 MPI_HOME=${HPCX_MPI_DIR} CUDA_HOME=/usr/local/cuda
popd
mv nccl-tests /opt
module unload mpi/hpcx

$COMMON_DIR/write_component_version.sh "NCCL" ${NCCL_VERSION}

# Remove installation files
rm -rf /tmp/${TARBALL}
rm -rf /tmp/nccl-${NCCL_VERSION}
