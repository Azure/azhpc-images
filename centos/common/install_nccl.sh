#!/bin/bash
set -ex

# Install NCCL
yum install -y rpm-build rpmdevtools
pushd /tmp
git clone https://github.com/NVIDIA/nccl.git
pushd nccl
git checkout v2.8.4-1
git cherry-pick -x 99b8a0393ffa379f3b0b81f3d5c0baa6aad7abef
git cherry-pick -x ef5f37461fdbf11104cf0ee13da80d80b84b4cbc
make -j src.build
make pkg.redhat.build
rpm -i ./build/pkg/rpm/x86_64/libnccl-2.8.4-1+cuda11.2.x86_64.rpm
rpm -i ./build/pkg/rpm/x86_64/libnccl-devel-2.8.4-1+cuda11.2.x86_64.rpm
rpm -i ./build/pkg/rpm/x86_64/libnccl-static-2.8.4-1+cuda11.2.x86_64.rpm
popd

# Install the nccl rdma sharp plugin
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
source /etc/profile.d/modules.sh
module load mpi/hpcx
git clone https://github.com/NVIDIA/nccl-tests.git
pushd nccl-tests
make MPI=1 MPI_HOME=${HPCX_MPI_DIR} CUDA_HOME=/usr/local/cuda
popd
mv nccl-tests /opt/.
module unload mpi/hpcx
