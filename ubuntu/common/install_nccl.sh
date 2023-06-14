#!/bin/bash
set -ex

# Set NCCL and CUDA driver versions
nccl_version=$(jq -r '.nccl."'"$DISTRIBUTION"'".version' <<< $COMPONENT_VERSIONS)
cuda_driver_version=$(jq -r '.cuda."'"$DISTRIBUTION"'".driver.version' <<< $COMPONENT_VERSIONS)

spack add nccl@$nccl_version cuda_arch=70,80,90 # V100,A100,H100 respectively
spack install --no-checksum

nccl_home=$(spack location -i nccl@$nccl_version)
export_nccl_ld="export LD_LIBRARY_PATH=$(echo $nccl_home)/lib:$LD_LIBRARY_PATH"
eval $export_nccl_ld
echo $export_nccl_ld | tee -a /etc/profile

# Install the nccl rdma sharp plugin
mkdir -p /usr/local/nccl-rdma-sharp-plugins
apt install -y zlib1g-dev
pushd $nccl_home
git clone https://github.com/Mellanox/nccl-rdma-sharp-plugins.git
pushd nccl-rdma-sharp-plugins
./autogen.sh
./configure --prefix=/usr/local/nccl-rdma-sharp-plugins --with-cuda=/usr/local/cuda
make
make install
popd
popd

# Build the nccl tests
export_modulepath="export MODULEPATH=$MODULEPATH:/usr/share/modules/modulefiles"
eval $export_modulepath
source /etc/profile.d/modules.sh
module load mpi/hpcx
git clone https://github.com/NVIDIA/nccl-tests.git
pushd nccl-tests
make MPI=1 MPI_HOME=$MPI_HOME CUDA_HOME=/usr/local/cuda NCCL_HOME=$(echo $nccl_home)
popd
mv nccl-tests /opt/.
module unload mpi/hpcx

$COMMON_DIR/write_component_version.sh "nccl" $nccl_version
