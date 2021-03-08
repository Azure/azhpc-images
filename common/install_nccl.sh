#!/bin/bash

# Install NCCL
sudo apt install -y build-essential devscripts debhelper fakeroot
cd /tmp
git clone https://github.com/NVIDIA/nccl.git
cd nccl/
git checkout v2.8.4-1
git cherry-pick -x ef5f37461fdbf11104cf0ee13da80d80b84b4cbc
git cherry-pick -x 99b8a0393ffa379f3b0b81f3d5c0baa6aad7abef
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
cd /tmp
git clone https://github.com/NVIDIA/nccl-tests.git
cd /tmp/nccl-tests
make MPI=1 MPI_HOME=/opt/hpcx-v2.7.4-gcc-MLNX_OFED_LINUX-5.2-1.0.4.0-ubuntu18.04-x86_64/ompi CUDA_HOME=/usr/local/cuda