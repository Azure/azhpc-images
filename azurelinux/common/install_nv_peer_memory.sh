#!/bin/bash
set -ex

# Download NV Peer Memory (GPU Direct RDMA)
NV_PEER_MEMORY_VERSION="1.3-0"
NV_PEER_MEMORY_VERSION_PREFIX=$(echo ${NV_PEER_MEMORY_VERSION} | awk -F- '{print $1}')
TARBALL="${NV_PEER_MEMORY_VERSION}.tar.gz"
NV_PEER_MEM_DOWNLOAD_URL="https://github.com/Mellanox/nv_peer_memory/archive/refs/tags/${TARBALL}"
wget ${NV_PEER_MEM_DOWNLOAD_URL}

# Install NV Peer Memory
dkms ldtarball $TARBALL
dkms status
dkms install nv_peer_mem -v $NV_PEER_MEMORY_VERSION_PREFIX

# Load nv_peer_mem
# modprobe nv_peer_mem
# lsmod | grep nv_peer_mem

$COMMON_DIR/write_component_version.sh "NV_PEER_MEMORY" ${NV_PEER_MEMORY_VERSION}