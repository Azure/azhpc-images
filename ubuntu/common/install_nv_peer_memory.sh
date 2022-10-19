#!/bin/bash
set -ex

# Install NV Peer Memory (GPU Direct RDMA)
sudo apt install -y dkms libnuma-dev
NV_PEER_MEMORY_VERSION="1.3-0"
NV_PEER_MEMORY_VERSION_PREFIX=$(echo ${NV_PEER_MEMORY_VERSION} | awk -F- '{print $1}')
TARBALL="${NV_PEER_MEMORY_VERSION}.tar.gz"
NV_PEER_MEM_DOWNLOAD_URL="https://github.com/Mellanox/nv_peer_memory/archive/refs/tags/${TARBALL}"
wget ${NV_PEER_MEM_DOWNLOAD_URL}
tar -xvf $TARBALL

pushd nv_peer_memory-${NV_PEER_MEMORY_VERSION}
./build_module.sh
popd

pushd /tmp
tar xzf /tmp/nvidia-peer-memory_${NV_PEER_MEMORY_VERSION_PREFIX}.orig.tar.gz
pushd nvidia-peer-memory-${NV_PEER_MEMORY_VERSION_PREFIX}/
# Fix for issue - https://github.com/Mellanox/nv_peer_memory/issues/106
sed -i s/1.2-0/${NV_PEER_MEMORY_VERSION}/g ./debian/changelog
dpkg-buildpackage -us -uc 
dpkg -i ../nvidia-peer-memory_${NV_PEER_MEMORY_VERSION}_all.deb 
apt-mark hold nvidia-peer-memory
dpkg -i ../nvidia-peer-memory-dkms_${NV_PEER_MEMORY_VERSION}_all.deb 
apt-mark hold nvidia-peer-memory-dkms
popd
popd

# load the nvidia-peermem coming as a part of NVIDIA GPU driver
# Reference - https://download.nvidia.com/XFree86/Linux-x86_64/510.85.02/README/nvidia-peermem.html
# Stop nv_peer_mem service
service nv_peer_mem stop
# unload nv_peer_mem
rmmod nv_peer_mem
# load nvidia-peermem
modprobe nvidia-peermem
# verify if loaded
lsmod | grep nvidia_peermem

$COMMON_DIR/write_component_version.sh "NV_PEER_MEMORY" ${NV_PEER_MEMORY_VERSION}
