#!/bin/bash
set -ex

source ${COMMON_DIR}/utilities.sh

#install the library
apt install -y rocm-hip-runtime hsa-rocr-dev hip-dev rocm-llvm-dev
apt install -y libdrm-amdgpu-amdgpu1 libdrm-dev
pip3 install CppHeaderParser argparse
apt remove -y rccl
rccl_metadata=$(get_component_config "rccl")
rccl_version=$(jq -r '.version' <<< $rccl_metadata)
rccl_commit=$(jq -r '.commit' <<< $rccl_metadata)

git clone --recursive https://github.com/ROCm/rccl.git
cd rccl
git checkout $rccl_commit
mkdir build
pushd build
CXX=/opt/rocm/bin/hipcc cmake -DCMAKE_PREFIX_PATH=/opt/rocm/ -DCMAKE_INSTALL_PREFIX=/opt/rccl ..
make -j$(nproc)
make install
popd
cd ..
rm -rf rccl
$COMMON_DIR/write_component_version.sh "RCCL" ${rccl_version}

sysctl kernel.numa_balancing=0
echo "kernel.numa_balancing=0" | tee -a /etc/sysctl.conf

git clone https://github.com/ROCmSoftwarePlatform/rccl-tests
pushd ./rccl-tests

source /opt/hpcx*/hpcx-init.sh
hpcx_load

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

roct_metadata=$(get_component_config "roctracer")
roct_version=$(jq -r '.version' <<< $roct_metadata)
roct_sha=$(jq -r '.sha256' <<< $roct_metadata)
roct_url=https://codeload.github.com/ROCm/roctracer/tar.gz/refs/tags/${roct_version}
$COMMON_DIR/download_and_verify.sh ${roct_url} ${roct_sha}
mv $roct_version roctracer.tar.gz
mkdir roctracer && tar -xvf roctracer.tar.gz --strip-components=1 -C roctracer
pushd roctracer
./build.sh
cd build
make install
popd

rocm_smi_metadata=$(get_component_config "rocm_smi_lib")
rocm_smi_version=$(jq -r '.version' <<< $rocm_smi_metadata)
rocm_smi_sha=$(jq -r '.sha256' <<< $rocm_smi_metadata)
rocm_smi_url=https://codeload.github.com/ROCm/rocm_smi_lib/tar.gz/refs/tags/${rocm_smi_version}
$COMMON_DIR/download_and_verify.sh ${rocm_smi_url} ${rocm_smi_sha}
mv $rocm_smi_version rocm_smi_lib.tar.gz
mkdir -p ./rocm_smi_lib/build && tar -xvf rocm_smi_lib.tar.gz --strip-components=1 -C rocm_smi_lib
pushd ./rocm_smi_lib/build
cmake ..
make -j $(nproc)
make install
popd

rm -rf rdma-perftest* rocm_smi_lib* roctracer*