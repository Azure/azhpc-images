#!/bin/bash

# Install NCCL
sudo apt install -y build-essential devscripts debhelper fakeroot
cd /tmp
git clone https://github.com/NVIDIA/nccl.git
cd nccl/
git checkout v2.8.4-1
make -j src.build
make pkg.debian.build
cd build/pkg/deb/
sudo dpkg -i libnccl2_2.8.4-1+cuda11.0_amd64.deb
sudo dpkg -i libnccl-dev_2.8.4-1+cuda11.0_amd64.deb

# Install the nccl rdma sharp plugin
cd /tmp
mkdir -p /usr/local/nccl-rdma-sharp-plugins
apt install -y zlib1g-dev
git clone https://github.com/Mellanox/nccl-rdma-sharp-plugins.git
cd nccl-rdma-sharp-plugins
git checkout v2.0.x-ar
./autogen.sh
./configure --prefix=/usr/local/nccl-rdma-sharp-plugins --with-cuda=/usr/local/cuda
make
make install

# Build the nccl tests
module load mpi/hpcx
git clone https://github.com/NVIDIA/nccl-tests.git
cd nccl-test
make MPI=1 MPI_HOME=/opt/hpcx-v2.7.4-gcc-MLNX_OFED_LINUX-5.2-1.0.4.0-ubuntu18.04-x86_64/ompi CUDA_HOME=/usr/local/cuda
module unload mpi/hpcx