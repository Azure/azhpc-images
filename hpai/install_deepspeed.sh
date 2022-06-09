#!/bin/bash
set -ex

apt update

# Install some required Python dependencies
apt install --yes \
	pdsh

pip3 install \
	matplotlib

COMMON_DIR=`pwd`
AISOFTWARE_DIR=/opt/aisoftware


mkdir -p ${AISOFTWARE_DIR}
cd ${AISOFTWARE_DIR}

git clone https://github.com/microsoft/DeepSpeed.git
cd DeepSpeed
git submodule update --init --recursive
git checkout azure
rm -rf $PWD/.git

pip3 install -r requirements/requirements.txt .


# Install Megatron-Deepspeed
cd ${COMMON_DIR}
pip3 install \
	regex

cd ${AISOFTWARE_DIR}
git clone https://github.com/microsoft/Megatron-DeepSpeed
cd Megatron-DeepSpeed
git checkout azure
rm -rf $PWD/.git
pip3 install .


# Setup a barebones DeepSpeed optimized environment
MODULE_FILES_DIRECTORY=/usr/share/modules/modulefiles/deepspeed
mkdir -p ${MODULE_FILES_DIRECTORY}

# DeepSpeed
cat << EOF >> ${MODULE_FILES_DIRECTORY}/deepspeed
#%Module 1.0
#
#  DeepSpeed
#
conflict        deepspeed
prepend-path    PATH                         ${AISOFTWARE_DIR}/DeepSpeed/bin
prepend-path    LD_LIBRARY_PATH              /usr/local/nccl-rdma-sharp-plugins/lib/
setenv          UCX_IB_PCI_RELAXED_ORDERING  on
setenv          UCX_NET_DEVICES              mlx5_0:1
setenv          UCX_IB_ENABLE_CUDA_AFFINITY  n
setenv          OPENUCX_VERSION              1.10.0
setenv          UCX_TLS                      rc
setenv          CUDA_DEVICE_ORDER            PCI_BUS_ID
setenv          NCCL_SOCKET_IFNAME           eth0
setenv          NCCL_DEBUG                   warn
setenv          NCCL_TOPO_FILE               /opt/microsoft/ndv4-topo.xml
setenv          NCCL_IB_PCI_RELAXED_ORDERING 1
setenv          NCCL_NET_GDR_LEVEL           5
setenv          NCCL_TREE_THRESHOLD          0
EOF
