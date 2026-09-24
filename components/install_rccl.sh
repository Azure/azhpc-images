#!/bin/bash
set -ex

source ${UTILS_DIR}/utilities.sh

rccl_metadata=$(get_component_config "rccl")
RCCL_TEST_CMAKE_ARGS=()
RCCL_TEST_GIT_ARGS=()
if [[ $DISTRIBUTION == "ubuntu26.04" ]]; then
    rocm_metadata=$(get_component_config "rocm")
    rocm_version=$(jq -r '.version' <<< "$rocm_metadata")
    RCCL_TEST_CMAKE_ARGS=(-DGPU_TARGETS="gfx90a;gfx942;gfx1250" -DCMAKE_INSTALL_RPATH=/opt/rocm/lib -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON)
    RCCL_TEST_GIT_ARGS=(--branch "therock-${rocm_version}")
fi

# Ubuntu 26.04 and Azure Linux 3 use packaged RCCL; build from source on other distros.
if [[ $DISTRIBUTION == "ubuntu26.04" ]]; then
    rccl_version=$(awk -F '"' '/^set\(PACKAGE_VERSION "/ {print $2; exit}' /opt/rocm/lib/cmake/rccl/rccl-config-version.cmake)
    [[ "$rccl_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
    write_component_version "RCCL" "$rccl_version"
elif [[ $DISTRIBUTION == "azurelinux3.0" ]]; then
    dnf install -y rccl rccl-devel rccl-unittests
    write_component_version "RCCL" "$(rpm -q --queryformat '%{VERSION}-%{RELEASE}' rccl)"
else
    # Ubuntu 24.04 temporarily needs a source build while using ROCm 6.4.
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
source /etc/profile.d/modules.sh
module load mpi/hpcx

# TODO: uncomment if we switch back to ROCm 7 on Ubuntu 24.04
# if [[ $DISTRIBUTION == "ubuntu24.04" || $DISTRIBUTION == "azurelinux3.0" || $DISTRIBUTION == "ubuntu26.04" ]]; then
if [[ $DISTRIBUTION == "azurelinux3.0" || $DISTRIBUTION == "ubuntu26.04" ]]; then
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
if [[ $DISTRIBUTION == "ubuntu26.04" ]]; then
    git clone --depth=1 --filter=blob:none --sparse "${RCCL_TEST_GIT_ARGS[@]}" https://github.com/ROCm/TheRock.git
    rccl_tests_commit=$(git -C TheRock rev-parse HEAD:rocm-systems)
    git init rocm-systems
    git -C rocm-systems remote add origin https://github.com/ROCm/rocm-systems.git
    git -C rocm-systems sparse-checkout set projects/rccl-tests
    git -C rocm-systems fetch --depth=1 --filter=blob:none origin "$rccl_tests_commit"
    git -C rocm-systems checkout --detach FETCH_HEAD
    rm -rf TheRock
else
    git clone --depth=1 --filter=blob:none --sparse https://github.com/ROCm/rocm-systems.git
fi
pushd ./rocm-systems
git sparse-checkout set projects/rccl-tests
pushd projects/rccl-tests

mkdir build
pushd build
# Add /opt/rocm/bin to PATH so the CMake build can find hipify-perl,
# hipconfig, and amdclang++ via its toolchain file.
PATH=/opt/rocm/bin:$PATH cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_PREFIX_PATH="$RCCL_PREFIX;/opt/rocm;$HPCX_MPI_DIR" \
    -DROCM_PATH=/opt/rocm \
    -DUSE_MPI=ON \
    "${RCCL_TEST_CMAKE_ARGS[@]}" \
    ..
make -j$(nproc)
# Place perf binaries directly under /opt/rccl-tests to preserve the layout
# expected by tests/test-definitions.sh.
cp ./*_perf $DEST_TEST_DIR/
popd  # build
popd  # projects/rccl-tests
popd  # rocm-systems
rm -rf rocm-systems
module unload mpi/hpcx

if [[ $DISTRIBUTION == *"ubuntu"* ]]; then
    apt install -y libpci-dev
fi
if [[ $DISTRIBUTION == "ubuntu26.04" ]]; then
    apt install -y libibumad-dev
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