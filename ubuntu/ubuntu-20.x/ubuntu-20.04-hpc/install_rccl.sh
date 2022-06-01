#!/bin/bash
set -ex

sudo apt-get install -y rocblas rccl-dev rccl-rdma-sharp-plugins

git clone https://github.com/ROCmSoftwarePlatform/rccl-tests
cd rccl-tests

HPCX="/opt/hpcx-v2.11-gcc-MLNX_OFED_LINUX-5-ubuntu20.04-cuda11-gdrcopy2"
HPCX+="-nccl2.11-x86_64/ompi/"
RCCLLIB="/opt/rocm/rccl/lib/librccl.so"
RCCLDIR="/opt/rocm/rccl"
HIPDIR="/opt/rocm/hip"

make MPI=1 MPI_HOME=$HPCX HIP_HOME=$HIPDIR NCCL_HOME=$RCCLDIR \
	CUSTOM_RCCL_LIB=$RCCLLIB
cd ..

DEST_TEST_DIR=/opt/rccl-tests
mkdir -p $DEST_TEST_DIR

cp rccl-tests/build/* $DEST_TEST_DIR
rm -r rccl-tests
