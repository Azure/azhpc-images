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

# Install gdrcopy
sudo apt install -y build-essential devscripts debhelper check libsubunit-dev fakeroot pkg-config dkms
git clone https://github.com/NVIDIA/gdrcopy.git
cd gdrcopy/packages/
CUDA=/usr/local/cuda ./build-deb-packages.sh 
sudo dpkg -i gdrdrv-dkms_2.3-1_amd64.Ubuntu18_04.deb
sudo apt-mark hold gdrdrv-dkms
sudo dpkg -i libgdrapi_2.3-1_amd64.Ubuntu18_04.deb
sudo apt-mark hold libgdrapi
sudo dpkg -i gdrcopy-tests_2.3-1_amd64.Ubuntu18_04.deb
sudo apt-mark hold gdrcopy-tests
sudo dpkg -i gdrcopy_2.3-1_amd64.Ubuntu18_04.deb
sudo apt-mark hold gdrcopy

# Install nvidia fabric manager (required for ND96asr_v4)
NVIDIA_FABRIC_MNGR_URL=http://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64/nvidia-fabricmanager-460_460.32.03-1_amd64.deb
$COMMON_DIR/download_and_verify.sh $NVIDIA_FABRIC_MNGR_URL "157da63c4f7823bb5ae4428891978345a079830629e23579e0c3126f42a4411c"
apt install -y ./nvidia-fabricmanager-460_460.32.03-1_amd64.deb
sudo apt-mark hold nvidia-fabricmanager-460
systemctl enable nvidia-fabricmanager
systemctl start nvidia-fabricmanager
