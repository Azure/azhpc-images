#!/bin/bash
set -ex

sudo apt-get install -y rocblas rccl-dev rccl-rdma-sharp-plugins

git clone https://github.com/ROCmSoftwarePlatform/rccl-tests
cd rccl-tests
make MPI=1 MPI_HOME=/opt/hpcx-v2.11-gcc-MLNX_OFED_LINUX-5-ubuntu20.04-cuda11-gdrcopy2-nccl2.11-x86_64/ompi/ HIP_HOME=/opt/rocm^Cip NCCL_HOME=/opt/rocm/rccl CUSTOM_RCCL_LIB=/opt/rocm/rccl/lib/librccl.so
cd ..

DEST_TEST_DIR=/opt/rccl-tests
mkdir -p $DEST_TEST_DIR

cp rccl-tests/build/* $DEST_TEST_DIR
rm -r rccl-tests
