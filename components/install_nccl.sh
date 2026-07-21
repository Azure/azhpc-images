#!/bin/bash
set -ex

source ${UTILS_DIR}/utilities.sh

# Set NCCL versions
nccl_metadata=$(get_component_config "nccl")
NCCL_VERSION=$(jq -r '.version' <<< $nccl_metadata)
NCCL_RDMA_SHARP_COMMIT=$(jq -r '.rdmasharpplugins.commit' <<< $nccl_metadata)

cuda_metadata=$(get_component_config "cuda")
CUDA_DRIVER_VERSION=$(jq -r '.driver.version' <<< $cuda_metadata)

TARBALL="v${NCCL_VERSION}.tar.gz"
NCCL_DOWNLOAD_URL=https://github.com/NVIDIA/nccl/archive/refs/tags/${TARBALL}

# Install NCCL
if [[ $DISTRIBUTION == *"ubuntu"* ]]; then
    apt install -y build-essential devscripts debhelper fakeroot
    # Comment the installation of libibverbs-dev to avoid conflicts on builds for bare metal 1P nodes
    # For VM it has been installed via the install_utils.sh or install_doca.sh
    apt install -y zlib1g-dev # libibverbs-dev 
elif [[ $DISTRIBUTION == "azurelinux3.0" ]]; then
    tdnf install -y rpm-build rpmdevtools autoconf automake git libtool
else
    # RHEL-family: AlmaLinux, Rocky Linux, RHEL, etc.
    yum install -y rpm-build rpmdevtools
fi

pushd /tmp
wget ${NCCL_DOWNLOAD_URL}
tar -xvf ${TARBALL}

pushd nccl-${NCCL_VERSION}
make -j $(( $(nproc) - 1 )) src.build
if [[ $DISTRIBUTION == *"ubuntu"* ]]; then
    make pkg.debian.build
    pushd build/pkg/deb/
    dpkg -i libnccl2_${NCCL_VERSION}+cuda${CUDA_DRIVER_VERSION}_${ARCHITECTURE_DISTRO}.deb
    apt-mark hold libnccl2
    dpkg -i libnccl-dev_${NCCL_VERSION}+cuda${CUDA_DRIVER_VERSION}_${ARCHITECTURE_DISTRO}.deb
    apt-mark hold libnccl-dev
    popd
elif [[ $DISTRIBUTION == "azurelinux3.0" ]]; then
    tdnf install -y "libnccl-${NCCL_VERSION}+cuda${CUDA_DRIVER_VERSION}.azl3"
    tdnf install -y "libnccl-devel-${NCCL_VERSION}+cuda${CUDA_DRIVER_VERSION}.azl3"
    tdnf install -y "libnccl-static-${NCCL_VERSION}+cuda${CUDA_DRIVER_VERSION}.azl3"    

    dnf_pin_packages "libnccl*"
else
    # RHEL-family: AlmaLinux, Rocky Linux, RHEL, etc.
    make pkg.redhat.build
    rpm -i ./build/pkg/rpm/x86_64/libnccl-${NCCL_VERSION}+cuda${CUDA_DRIVER_VERSION}.x86_64.rpm
    rpm -i ./build/pkg/rpm/x86_64/libnccl-devel-${NCCL_VERSION}+cuda${CUDA_DRIVER_VERSION}.x86_64.rpm
    rpm -i ./build/pkg/rpm/x86_64/libnccl-static-${NCCL_VERSION}+cuda${CUDA_DRIVER_VERSION}.x86_64.rpm
    dnf_pin_packages "libnccl*"
fi
popd

# Install the nccl rdma sharp plugin. Skip for non-IB SKUs (no DOCA-OFED, no SHARP, no GPUDirect RDMA)
if [[ "$(sku_network_mode)" == "standard_ib" ]]; then
    mkdir -p /usr/local/nccl-rdma-sharp-plugins
    git clone https://github.com/Mellanox/nccl-rdma-sharp-plugins.git
    pushd nccl-rdma-sharp-plugins
    git checkout ${NCCL_RDMA_SHARP_COMMIT}

    if [[ "$DISTRIBUTION" == "azurelinux3.0" ]]; then
        libtoolize --verbose
    fi

    ./autogen.sh
    ./configure --prefix=/usr/local/nccl-rdma-sharp-plugins --with-cuda=/usr/local/cuda
    make
    make install
    popd
    write_component_version "NCCL-RDMA_SHARP_PLUGIN" ${NCCL_RDMA_SHARP_COMMIT}
fi

# Build the nccl tests
source /etc/profile.d/modules.sh
module load mpi/hpcx
git clone https://github.com/NVIDIA/nccl-tests.git
pushd nccl-tests
make MPI=1 MPI_HOME=${HPCX_MPI_DIR} CUDA_HOME=/usr/local/cuda
popd
mv nccl-tests /opt/.
module unload mpi/hpcx
popd

write_component_version "NCCL" ${NCCL_VERSION}

# Remove installation files
rm -rf /tmp/${TARBALL}
rm -rf /tmp/nccl-${NCCL_VERSION}
