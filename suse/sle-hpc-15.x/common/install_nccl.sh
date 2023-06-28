#!/bin/bash
set -ex

# Install NCCL
# Optimized primitives for inter-GPU communication.

# add rpm build tools
zypper install -y -l rpm-build rpmdevtools git

CUDA_MAJOR=$( echo ${CUDA_VERSION} | cut -d "." -f 1)
CUDA_MINOR=$( echo ${CUDA_VERSION} | cut -d "." -f 2)

TARBALL=$(basename ${NCCL_DOWNLOAD_URL})

pushd /tmp
wget ${NCCL_DOWNLOAD_URL}
tar -xvf ${TARBALL}

pushd nccl-${NCCL_VERSION}

# if you need to limit the number of parallel runs on smaller machines
#mem=$(cat /proc/meminfo | head -1 | sed -e "s/^[^ ]\+[ ]\+\([^ ]\+\)[ ]\+.*/\\1/")
#core=$(cat /proc/cpuinfo | grep processor | wc -l)
#cnt=$(( a=mem/(512*1024), a < core ? a : core ))
#make -j $cnt src.build NVCC_GENCODE="-gencode=arch=compute_80,code=sm_80"

# You should define NVCC_GENCODE in your environment to the minimal set
# of archs to reduce compile time.
#make -j src.build NVCC_GENCODE="-gencode=arch=compute_80,code=sm_80"

make -j src.build

# build rpm packages
make pkg.redhat.build
rpm -i ./build/pkg/rpm/x86_64/libnccl-${NCCL_VERSION}+cuda${CUDA_MAJOR}.${CUDA_MINOR}.x86_64.rpm
rpm -i ./build/pkg/rpm/x86_64/libnccl-devel-${NCCL_VERSION}+cuda${CUDA_MAJOR}.${CUDA_MINOR}.x86_64.rpm
rpm -i ./build/pkg/rpm/x86_64/libnccl-static-${NCCL_VERSION}+cuda${CUDA_MAJOR}.${CUDA_MINOR}.x86_64.rpm
popd
rm -rf nccl-${NCCL_VERSION} $TARBALL

# Install the nccl rdma sharp plugin
# we need the packages: autoconf automake libtool rdma-core-devel
mkdir -p /usr/local/nccl-rdma-sharp-plugins
git clone https://github.com/Mellanox/nccl-rdma-sharp-plugins.git
pushd nccl-rdma-sharp-plugins
./autogen.sh
./configure --prefix=/usr/local/nccl-rdma-sharp-plugins --with-cuda=/usr/local/cuda
make
make install
popd
rm -rf nccl-rdma-sharp-plugins


# Build the nccl tests
source /etc/profile.d/lmod.sh
module load mpi/hpcx
git clone https://github.com/NVIDIA/nccl-tests.git
pushd nccl-tests
make MPI=1 MPI_HOME=${HPCX_MPI_DIR} CUDA_HOME=/usr/local/cuda
popd
mv nccl-tests /opt
module purge
popd


$COMMON_DIR/write_component_version.sh "NCCL" ${NCCL_VERSION}

# Remove installation files
rm -rf /tmp/${TARBALL}
rm -rf /tmp/nccl-${NCCL_VERSION}
