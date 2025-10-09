#!/bin/bash
set -ex

source ${UTILS_DIR}/utilities.sh

rccl_metadata=$(get_component_config "rccl")
rccl_branch=$(jq -r '.branch' <<< $rccl_metadata)
rccl_commit=$(jq -r '.commit' <<< $rccl_metadata)
rccl_version=$(jq -r '.version' <<< $rccl_metadata)
rccl_url=$(jq -r '.url' <<< $rccl_metadata)
rccl_sha256=$(jq -r '.sha256' <<< $rccl_metadata)
#the content of this tar ball is rccl but its name is misleading
TARBALL=$(basename ${rccl_url})
rccl_folder=rccl-$(basename $TARBALL .tar.gz)

# due to https://github.com/ROCm/rccl/issues/1877
# we need to resort to doing a git clone instead of downloading the rccl tarball, by specifying a branch to clone
if [[ $rccl_branch != "" && $rccl_branch != "null" ]]; then
    git clone --branch ${rccl_branch} https://github.com/ROCm/rccl.git ${rccl_folder}
    pushd ${rccl_folder}
    git checkout ${rccl_commit}
    popd
else
    download_and_verify ${rccl_url} ${rccl_sha256}
    tar -xzf ${TARBALL}
fi
mkdir ./${rccl_folder}/build
pushd ./${rccl_folder}/build

# aggressively crank up the number of compiler given that we have 2TB of memory to spare on MI300X
sed -i -E 's/(target_compile_options\(\s*rccl\s+PRIVATE[^)]*-parallel-jobs=)12/\196/' ../CMakeLists.txt

CXX=/opt/rocm/bin/hipcc CMAKE_POLICY_VERSION_MINIMUM=3.5 cmake -DCMAKE_PREFIX_PATH=/opt/rocm/ -DCMAKE_INSTALL_PREFIX=/opt/rccl ..
make -j$(nproc)
make install
popd
rm -rf ${TARBALL} ${rccl_folder}
write_component_version "RCCL" ${rccl_version}

if [[ $DISTRIBUTION == *"ubuntu"* ]]; then
    sysctl kernel.numa_balancing=0
fi
echo "kernel.numa_balancing=0" | tee -a /etc/sysctl.conf

git clone https://github.com/ROCmSoftwarePlatform/rccl-tests
pushd ./rccl-tests

source /opt/hpcx*/hpcx-init.sh
hpcx_load

RCCLLIB="/opt/rccl/lib/librccl.so"
RCCLDIR="/opt/rccl"

echo "gfx942" > target.lst
echo "gfx90a" >> target.lst

if [[ $DISTRIBUTION == *"ubuntu"* ]]; then
    ROCM_TARGET_LST=$(pwd)/target.lst make -j$(nproc) MPI=1 NCCL_HOME=$RCCLDIR CUSTOM_RCCL_LIB=$RCCLLIB
elif [[ $DISTRIBUTION == "azurelinux3.0" ]]; then
    mkdir -p build/hipify
    hipify-perl -quiet-warnings verifiable/verifiable.h > build/hipify/verifiable.h
    ROCM_TARGET_LST=$(pwd)/target.lst make -j$(nproc) MPI=1 MPI_HOME=$HPCX NCCL_HOME=$RCCLDIR CUSTOM_RCCL_LIB=$RCCLLIB
fi
popd

if [[ $DISTRIBUTION == *"ubuntu"* ]]; then
    apt install -y libpci-dev
fi

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