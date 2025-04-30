#!/bin/bash
set -ex

source ${COMMON_DIR}/utilities.sh

#install the rccl library
apt install libstdc++-12-dev
apt remove -y rccl
rccl_metadata=$(get_component_config "rccl")
rccl_version=$(jq -r '.version' <<< $rccl_metadata)
rccl_url=$(jq -r '.url' <<< $rccl_metadata)
rccl_sha256=$(jq -r '.sha256' <<< $rccl_metadata)
#the content of this tar ball is rccl but its name is misleading
TARBALL=$(basename ${rccl_url})
rccl_folder=rccl-$(basename $TARBALL .tar.gz)

$COMMON_DIR/download_and_verify.sh ${rccl_url} ${rccl_sha256}
tar -xzf ${TARBALL}
mkdir ./${rccl_folder}/build
pushd ./${rccl_folder}/build
CXX=/opt/rocm/bin/hipcc cmake -DCMAKE_PREFIX_PATH=/opt/rocm/ -DCMAKE_INSTALL_PREFIX=/opt/rccl ..
make -j$(nproc)
make install
pushd ../..
rm -rf ${TARBALL} ${rccl_folder}
$COMMON_DIR/write_component_version.sh "RCCL" ${rccl_version}

sysctl kernel.numa_balancing=0
echo "kernel.numa_balancing=0" | tee -a /etc/sysctl.conf


git clone https://github.com/ROCmSoftwarePlatform/rccl-tests
pushd ./rccl-tests

source /opt/hpcx*/hpcx-init.sh
hpcx_load

#HPCX="/opt/hpcx-v2.16-gcc-mlnx_ofed-ubuntu22.04-cuda12-gdrcopy2"
#HPCX+="-nccl2.18-x86_64/ompi/"
RCCLLIB="/opt/rccl/lib/librccl.so"
RCCLDIR="/opt/rccl"


echo "gfx942" > target.lst
echo "gfx90a" >> target.lst

ROCM_TARGET_LST=$(pwd)/target.lst make MPI=1 \
        NCCL_HOME=$RCCLDIR CUSTOM_RCCL_LIB=$RCCLLIB

popd

DEST_TEST_DIR=/opt/rccl-tests
mkdir -p $DEST_TEST_DIR

cp -r ./rccl-tests/build/* $DEST_TEST_DIR
rm -rf rccl-tests

git clone https://github.com/ROCm/rdma-perftest
mkdir -p /opt/rocm-perftest
pushd ./rdma-perftest
./autogen.sh
./configure --enable-rocm --with-rocm=/opt/rocm --prefix=/opt/rocm-perftest/
make -j$(nproc)
make install

popd
rm -rf rdma-perftest