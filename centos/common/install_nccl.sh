#!/bin/bash
set -ex

# Install NCCL
yum install -y rpm-build rpmdevtools
pushd /tmp
git clone https://github.com/NVIDIA/nccl.git
pushd nccl
git checkout v2.9.9-1
make -j src.build
make pkg.redhat.build
rpm -i ./build/pkg/rpm/x86_64/libnccl-2.9.9-1+cuda11.2.x86_64.rpm
echo "exclude=libnccl" | sudo tee -a /etc/yum.conf
rpm -i ./build/pkg/rpm/x86_64/libnccl-devel-2.9.9-1+cuda11.2.x86_64.rpm
echo "exclude=libnccl-devel" | sudo tee -a /etc/yum.conf
rpm -i ./build/pkg/rpm/x86_64/libnccl-static-2.9.9-1+cuda11.2.x86_64.rpm
echo "exclude=libnccl-static" | sudo tee -a /etc/yum.conf
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
