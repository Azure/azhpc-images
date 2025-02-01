#!/bin/bash
set -ex

source ${COMMON_DIR}/utilities.sh

#update CMAKE
cmake_metadata=$(get_component_config "cmake")
cmake_version=$(jq -r '.version' <<< $cmake_metadata)
cmake_url=$(jq -r '.url' <<< $cmake_metadata)
cmake_sha256=$(jq -r '.sha256' <<< $cmake_metadata)
TARBALL="cmake-${cmake_version}-linux-x86_64.tar.gz"

${COMMON_DIR}/download_and_verify.sh ${cmake_url} ${cmake_sha256}
tar -xzf ${TARBALL}
pushd cmake-${cmake_version}-linux-x86_64
cp -f bin/{ccmake,cmake,cpack,ctest} /usr/local/bin
cp -rf share/cmake-* /usr/local/share/
popd
rm -rf cmake-${cmake_version}-linux-x86_64*
hash -r
$COMMON_DIR/write_component_version.sh "CMAKE" ${cmake_version}

apt install libstdc++-12-dev
apt remove -y rccl
pushd ~
git clone https://github.com/rocm/rccl
popd
mkdir ~/rccl/build
pushd ~/rccl/build
CXX=/opt/rocm/bin/hipcc cmake -DCMAKE_PREFIX_PATH=/opt/rocm/ -DCMAKE_INSTALL_PREFIX=/opt/rccl ..
make -j
make install
popd

pushd ~

sysctl kernel.numa_balancing=0
echo "kernel.numa_balancing=0" | tee -a /etc/sysctl.conf


git clone https://github.com/ROCmSoftwarePlatform/rccl-tests
pushd ~/rccl-tests

source /opt/hpcx*/hpcx-init.sh
hpcx_load

HPCX="/opt/hpcx-v2.16-gcc-mlnx_ofed-ubuntu22.04-cuda12-gdrcopy2"
HPCX+="-nccl2.18-x86_64/ompi/"
RCCLLIB="/opt/rccl/lib/librccl.so"
RCCLDIR="/opt/rccl"


echo "gfx942" > target.lst
echo "gfx90a" >> target.lst

ROCM_TARGET_LST=$(pwd)/target.lst make MPI=1 \
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
make -j
make install

popd
