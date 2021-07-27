#!/bin/bash
set -ex

$COMMON_DIR/install_nvidiagpudriver.sh

# Install NV Peer Memory (GPU Direct RDMA)
sudo apt install -y dkms libnuma-dev
git clone https://github.com/Mellanox/nv_peer_memory.git
cd nv_peer_memory*/
git checkout 1_1_0_Release
./build_module.sh 
cd /tmp
tar xzf /tmp/nvidia-peer-memory_1.1.orig.tar.gz
cd nvidia-peer-memory-1.1/
dpkg-buildpackage -us -uc 
sudo dpkg -i ../nvidia-peer-memory_1.1-0_all.deb 
sudo apt-mark hold nvidia-peer-memory
sudo dpkg -i ../nvidia-peer-memory-dkms_1.1-0_all.deb 
sudo apt-mark hold nvidia-peer-memory-dkms
sudo modprobe nv_peer_mem
lsmod | grep nv

sudo bash -c "cat > /etc/modules-load.d/nv_peer_mem.conf" <<'EOF'
nv_peer_mem
EOF

sudo systemctl enable nv_peer_mem.service
