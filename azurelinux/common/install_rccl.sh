#!/bin/bash
set -ex

tdnf install -y libstdc++-devel

# tdnf remove -y rccl

pushd ~
git clone https://github.com/rocm/rccl
popd
mkdir ~/rccl/build
pushd ~/rccl/build
CXX=/opt/rocm/bin/hipcc cmake -DCMAKE_PREFIX_PATH=/opt/rocm/ -DCMAKE_INSTALL_PREFIX=/opt/rccl ..
make -j $(nproc)
make install
popd

pushd ~

# sysctl kernel.numa_balancing=0
echo "kernel.numa_balancing=0" | tee -a /etc/sysctl.conf


git clone https://github.com/ROCmSoftwarePlatform/rccl-tests
pushd ~/rccl-tests

source /opt/hpcx*/hpcx-init.sh
hpcx_load

HPCX="/opt/hpcx-v2.18-gcc-mlnx_ofed-redhat8-cuda12-x86_64/"
HPCX+="ompi/"
RCCLLIB="/opt/rccl/lib/librccl.so"
RCCLDIR="/opt/rccl"


echo "gfx942" > target.lst
echo "gfx90a" >> target.lst

mkdir -p build/hipify
hipify-perl -quiet-warnings verifiable/verifiable.h > build/hipify/verifiable.h

ROCM_TARGET_LST=$(pwd)/target.lst make MPI=1 MPI_HOME=$HPCX \
        NCCL_HOME=$RCCLDIR CUSTOM_RCCL_LIB=$RCCLLIB

popd

DEST_TEST_DIR=/opt/rccl-tests
mkdir -p $DEST_TEST_DIR

cp -r ~/rccl-tests/build/* $DEST_TEST_DIR
rm -rf rccl-tests

git clone https://github.com/ROCm/rdma-perftest
mkdir /opt/rocm-perftest
pushd ~/rdma-perftest
./autogen.sh
./configure --enable-rocm --with-rocm=/opt/rocm --prefix=/opt/rocm-perftest/
make -j $(nproc)
make install

popd
