#!/bin/bash
set -ex

$COMMON_DIR/install_nvidiagpudriver.sh

# Install NV Peer Memory (GPU Direct RDMA)
sudo apt install -y dkms libnuma-dev
NV_PEER_MEMORY_VERSION="1.2-0"
NV_PEER_MEMORY_VERSION_PREFIX=$(echo ${NV_PEER_MEMORY_VERSION} | awk -F- '{print $1}')
$COMMON_DIR/write_component_version.sh "NV_PEER_MEMORY" ${NV_PEER_MEMORY_VERSION}
git clone https://github.com/gpudirect/nv_peer_memory.git

cd nv_peer_memory
./build_module.sh 
cd /tmp
tar xzf /tmp/nvidia-peer-memory_${NV_PEER_MEMORY_VERSION_PREFIX}.orig.tar.gz
cd nvidia-peer-memory-${NV_PEER_MEMORY_VERSION_PREFIX}/
dpkg-buildpackage -us -uc 
sudo dpkg -i ../nvidia-peer-memory_${NV_PEER_MEMORY_VERSION}_all.deb 
sudo apt-mark hold nvidia-peer-memory
sudo dpkg -i ../nvidia-peer-memory-dkms_${NV_PEER_MEMORY_VERSION}_all.deb 
sudo apt-mark hold nvidia-peer-memory-dkms
sudo modprobe nv_peer_mem
lsmod | grep nv

sudo bash -c "cat > /etc/modules-load.d/nv_peer_mem.conf" <<'EOF'
nv_peer_mem
EOF

sudo systemctl enable nv_peer_mem.service
