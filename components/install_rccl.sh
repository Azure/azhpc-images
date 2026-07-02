#!/bin/bash
set -ex

source ${UTILS_DIR}/utilities.sh

# On Ubuntu 24.04 and Azure Linux 3, RCCL comes from ROCm packages; build from source on other distros
if [[ $DISTRIBUTION == "azurelinux3.0" ]]; then
    tdnf install -y rccl rccl-devel rccl-unittests
    write_component_version "RCCL" "$(rpm -q --queryformat '%{VERSION}-%{RELEASE}' rccl)"
elif [[ $DISTRIBUTION != "ubuntu24.04" ]]; then
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
    sed -i -E "s/(target_compile_options\(\s*rccl\s+PRIVATE[^)]*-parallel-jobs=)12/\1$(nproc)/" ../CMakeLists.txt
    # Clamp link-time parallelism: amdgcn-link is memory-hungry and the upstream default (16)
    # OOM-kills the linker on smaller builders (e.g. 32 GB ARM). Mirror the later RCCL logic of
    # reserving ~16 GB per linker job, with a hard cap of 16 (also clamp to >= 1).
    mem_gb=$(awk '/^MemTotal:/ {printf "%d", $2/1024/1024}' /proc/meminfo)
    num_linker_jobs=$(( (mem_gb + 15) / 16 ))
    if (( num_linker_jobs > 16 )); then num_linker_jobs=16; fi
    if (( num_linker_jobs < 1  )); then num_linker_jobs=1;  fi
    echo "RCCL link parallelism: detected ${mem_gb} GB RAM -> -parallel-jobs=${num_linker_jobs}"
    sed -i -E "s/(target_link_options\(\s*rccl\s+PRIVATE[^)]*-parallel-jobs=)[0-9]+/\1${num_linker_jobs}/" ../CMakeLists.txt

    CXX=/opt/rocm/bin/hipcc CMAKE_POLICY_VERSION_MINIMUM=3.5 cmake -DCMAKE_PREFIX_PATH=/opt/rocm/ -DCMAKE_INSTALL_PREFIX=/opt/rccl ..
    make -j$(nproc)
    make install
    popd
    rm -rf ${TARBALL} ${rccl_folder}
    write_component_version "RCCL" ${rccl_version}
fi

if [[ $DISTRIBUTION == *"ubuntu"* ]]; then
    sysctl kernel.numa_balancing=0
    sysctl vm.max_map_count=1048576
fi
echo "kernel.numa_balancing=0" | tee -a /etc/sysctl.conf
echo "vm.max_map_count=1048576" | tee -a /etc/sysctl.conf

# Build rccl-tests from the modern home in ROCm/rocm-systems using its CMake
# build system. This supersedes the legacy ROCmSoftwarePlatform/rccl-tests
# Makefile flow and handles hipify automatically for all distros.
source /opt/hpcx*/hpcx-init.sh
hpcx_load

if [[ $DISTRIBUTION == "ubuntu24.04" || $DISTRIBUTION == "azurelinux3.0" ]]; then
    # RCCL ships via ROCm distro packages and lives in /opt/rocm
    RCCL_PREFIX="/opt/rocm"
else
    # RCCL was built from source above and installed in /opt/rccl
    RCCL_PREFIX="/opt/rccl"
fi

DEST_TEST_DIR=/opt/rccl-tests
mkdir -p $DEST_TEST_DIR

# Sparse-clone only the rccl-tests subproject of rocm-systems to keep the
# clone small.
# TODO: revert to ROCm/rocm-systems once the ctaPolicy guard fix is merged
# upstream (github.com/normanvuong/rocm-systems branch
# users/normanvuong/rocm_ctapolicy_guard).
git clone --depth=1 --filter=blob:none --sparse --branch users/normanvuong/rocm_ctapolicy_guard https://github.com/normanvuong/rocm-systems.git
pushd ./rocm-systems
git sparse-checkout set projects/rccl-tests
pushd projects/rccl-tests

mkdir build
pushd build
# Add /opt/rocm/bin to PATH so the CMake build can find hipify-perl,
# hipconfig, and amdclang++ via its toolchain file.
PATH=/opt/rocm/bin:$PATH cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_PREFIX_PATH="$RCCL_PREFIX;/opt/rocm;$HPCX" \
    -DROCM_PATH=/opt/rocm \
    -DUSE_MPI=ON \
    ..
make -j$(nproc)
# Place perf binaries directly under /opt/rccl-tests to preserve the layout
# expected by tests/test-definitions.sh.
cp ./*_perf $DEST_TEST_DIR/
popd  # build
popd  # projects/rccl-tests
popd  # rocm-systems
rm -rf rocm-systems

if [[ $DISTRIBUTION == *"ubuntu"* ]]; then
    apt install -y libpci-dev
fi

# Upstream linux-rdma/perftest has full ROCm/HIP support, superseding the
# dormant ROCm/rdma-perftest fork.
git clone https://github.com/linux-rdma/perftest.git
mkdir -p /opt/rocm-perftest
pushd ./perftest
./autogen.sh
./configure --enable-rocm --with-rocm=/opt/rocm --prefix=/opt/rocm-perftest/
make -j$(nproc)
make install

popd
rm -rf perftest