#!/bin/bash
set -ex

# Install NCCL
yum install -y rpm-build rpmdevtools
NCCL_VERSION="2.11.4-1"
$COMMON_DIR/write_component_version.sh "NCCL" ${NCCL_VERSION}
TARBALL="v${NCCL_VERSION}.tar.gz"
NCCL_DOWNLOAD_URL=https://github.com/NVIDIA/nccl/archive/refs/tags/${TARBALL}
pushd /tmp
wget ${NCCL_DOWNLOAD_URL}
tar -xvf ${TARBALL}

pushd nccl-${NCCL_VERSION}
make -j src.build
make pkg.redhat.build
rpm -i ./build/pkg/rpm/x86_64/libnccl-${NCCL_VERSION}+cuda11.4.x86_64.rpm
echo "exclude=libnccl" | sudo tee -a /etc/yum.conf
rpm -i ./build/pkg/rpm/x86_64/libnccl-devel-${NCCL_VERSION}+cuda11.4.x86_64.rpm
echo "exclude=libnccl-devel" | sudo tee -a /etc/yum.conf
rpm -i ./build/pkg/rpm/x86_64/libnccl-static-${NCCL_VERSION}+cuda11.4.x86_64.rpm
echo "exclude=libnccl-static" | sudo tee -a /etc/yum.conf
popd

# Install the nccl rdma sharp plugin
mkdir -p /usr/local/nccl-rdma-sharp-plugins
git clone https://github.com/Mellanox/nccl-rdma-sharp-plugins.git
pushd nccl-rdma-sharp-plugins
./autogen.sh
./configure --prefix=/usr/local/nccl-rdma-sharp-plugins --with-cuda=/usr/local/cuda
make
make install
popd
popd

# Build the nccl tests
source /etc/profile.d/modules.sh
module load mpi/hpcx
NCCL_TESTS_VERSION="2.13.3"
TARBALL="v${NCCL_TESTS_VERSION}.tar.gz"
NCCL_TESTS_DOWNLOAD_URL="https://github.com/NVIDIA/nccl-tests/archive/refs/tags/${TARBALL}"
wget ${NCCL_TESTS_DOWNLOAD_URL}
tar -xvf ${TARBALL}
pushd nccl-tests-${NCCL_TESTS_VERSION}
make MPI=1 MPI_HOME=${HPCX_MPI_DIR} CUDA_HOME=/usr/local/cuda
popd
mv nccl-tests-${NCCL_TESTS_VERSION} /opt/nccl-tests
module unload mpi/hpcx

# Remove installation files
rm -rf /tmp/${TARBALL}
rm -rf /tmp/nccl-${NCCL_VERSION}
