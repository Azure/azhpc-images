#!/bin/bash
set -ex

# Install NCCL
apt install -y build-essential devscripts debhelper fakeroot
cd /tmp
git clone https://github.com/NVIDIA/nccl.git
cd nccl/
git checkout v2.9.9-1
make -j src.build
make pkg.debian.build
cd build/pkg/deb/
dpkg -i libnccl2_2.9.9-1+cuda11.2_amd64.deb
sudo apt-mark hold libnccl2
dpkg -i libnccl-dev_2.9.9-1+cuda11.2_amd64.deb
sudo apt-mark hold libnccl-dev

# Install the nccl rdma sharp plugin
cd /tmp
mkdir -p /usr/local/nccl-rdma-sharp-plugins
apt install -y zlib1g-dev
git clone https://github.com/Mellanox/nccl-rdma-sharp-plugins.git
cd nccl-rdma-sharp-plugins
./autogen.sh
./configure --prefix=/usr/local/nccl-rdma-sharp-plugins --with-cuda=/usr/local/cuda
make
make install

# Build the nccl tests
source /etc/profile.d/modules.sh
module load mpi/hpcx
cd /opt
git clone https://github.com/NVIDIA/nccl-tests.git
cd /opt/nccl-tests
make MPI=1 MPI_HOME=${HPCX_MPI_DIR} CUDA_HOME=/usr/local/cuda
module unload mpi/hpcx

# NCCL-Tests Preset Run Config
cat << EOF >> /etc/nccl.conf
NCCL_IB_PCI_RELAXED_ORDERING=1
CUDA_DEVICE_ORDER=PCI_BUS_ID
NCCL_TOPO_FILE=/opt/microsoft/ndv4-topo.xml
NCCL_SOCKET_IFNAME=eth0
EOF
