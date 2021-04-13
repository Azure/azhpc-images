#!/bin/bash
set -ex

$COMMON_DIR/install_nvidiagpudriver.sh

# Nvidia driver
NVIDIA_DRIVER_URL=https://download.nvidia.com/XFree86/Linux-x86_64/460.32.03/NVIDIA-Linux-x86_64-460.32.03.run
$COMMON_DIR/download_and_verify.sh $NVIDIA_DRIVER_URL "4f2122fc23655439f214717c4c35ab9b4f5ab8537cddfdf059a5682f1b726061"
sudo bash NVIDIA-Linux-x86_64-460.32.03.run --silent

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
sudo dpkg -i ../nvidia-peer-memory-dkms_1.1-0_all.deb 
sudo modprobe nv_peer_mem
lsmod | grep nv

sudo bash -c "cat > /etc/modules-load.d/nv_peer_mem.conf" <<'EOF'
nv_peer_mem
EOF

sudo systemctl enable nv_peer_mem.service

# Install gdrcopy
sudo apt install -y check libsubunit0 libsubunit-dev build-essential devscripts debhelper check libsubunit-dev fakeroot
git clone https://github.com/NVIDIA/gdrcopy.git
cd gdrcopy/packages/
CUDA=/usr/local/cuda ./build-deb-packages.sh 
sudo dpkg -i gdrdrv-dkms_2.2-1_amd64.deb 
sudo dpkg -i gdrcopy_2.2-1_amd64.deb
