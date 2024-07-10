#!/bin/bash
set -ex

#sudo apt-get install -y rocblas rccl-dev rccl-rdma-sharp-plugins
sudo apt install libstdc++-12-dev
sudo apt remove -y rccl
cd ~
git clone https://github.com/rocm/rccl
cd rccl
mkdir build
cd build
CXX=/opt/rocm/bin/hipcc cmake -DCMAKE_PREFIX_PATH=/opt/rocm/ -DCMAKE_INSTALL_PREFIX=/opt/rccl ..
make -j 32
sudo make install
cd ~


sudo sysctl kernel.numa_balancing=0
echo "kernel.numa_balancing=0" | sudo tee -a /etc/sysctl.conf


git clone https://github.com/ROCmSoftwarePlatform/rccl-tests
cd rccl-tests

source /opt/hpcx-v2.16-gcc-mlnx_ofed-ubuntu22.04-cuda12-gdrcopy2-nccl2.18-x86_64/hpcx-init.sh
hpcx_load

HPCX="/opt/hpcx-v2.16-gcc-mlnx_ofed-ubuntu22.04-cuda12-gdrcopy2"
HPCX+="-nccl2.18-x86_64/ompi/"
RCCLLIB="/opt/rccl/lib/librccl.so"
RCCLDIR="/opt/rccl"


echo "gfx942" > target.lst
echo "gfx90a" >> target.lst

ROCM_TARGET_LST=$(pwd)/target.lst make MPI=1 \
        NCCL_HOME=$RCCLDIR CUSTOM_RCCL_LIB=$RCCLLIB

cd ~

DEST_TEST_DIR=/opt/rccl-tests
sudo mkdir -p $DEST_TEST_DIR

sudo cp -r ~/rccl-tests/build/* $DEST_TEST_DIR
rm -rf rccl-tests

cd ~
git clone https://github.com/ROCm/rdma-perftest
sudo mkdir /opt/rocm-perftest
cd rdma-perftest
./autogen.sh
./configure --enable-rocm --with-rocm=/opt/rocm --prefix=/opt/rocm-perftest/
make -j 32
sudo make install

cd ~
sudo ./install_rdc.sh

