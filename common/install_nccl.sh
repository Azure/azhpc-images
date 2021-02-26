#!/bin/bash

# Install NCCL
sudo apt install -y build-essential devscripts debhelper fakeroot
cd /tmp
git clone https://github.com/NVIDIA/nccl.git
cd nccl/
git checkout v2.8.3-1
git cherry-pick -x 99b8a0393ffa379f3b0b81f3d5c0baa6aad7abef
make -j src.build
make pkg.debian.build
cd build/pkg/deb/
sudo dpkg -i libnccl2_2.8.3-1+cuda11.0_amd64.deb
sudo dpkg -i libnccl-dev_2.8.3-1+cuda11.0_amd64.deb

# Install the nccl rdma sharp plugin
# cd /tmp
# mkdir -p /usr/local/nccl-rdma-sharp-plugins
# sudo apt install -y zlib1g-dev
# git clone https://github.com/Mellanox/nccl-rdma-sharp-plugins.git
# cd nccl-rdma-sharp-plugins
# git checkout v2.0.x-ar
# ./autogen.sh
# ./configure --prefix=/usr/local/nccl-rdma-sharp-plugins --with-cuda=/usr/local/cuda
# make
# sudo make install

# Build the nccl tests
cd /opt/msft
HPCX_DIR=hpcx-v
git clone https://github.com/NVIDIA/nccl-tests.git
. /opt/${HPCX_DIR}*/hpcx-init.sh
hpcx_load
cd nccl-tests
make MPI=1