#!/bin/bash
set -ex

# Nvidia driver
cd /mnt
NVIDIA_DRIVER_URL=https://download.nvidia.com/XFree86/Linux-x86_64/460.27.04/NVIDIA-Linux-x86_64-460.27.04.run
wget $NVIDIA_DRIVER_URL
chmod 755 NVIDIA-Linux-x86_64-450.80.02.run
sudo ./NVIDIA-Linux-x86_64-450.80.02.run -s

# Install Cuda
wget https://developer.download.nvidia.com/compute/cuda/11.0.3/local_installers/cuda_11.0.3_450.51.06_linux.run
chmod +x cuda_11.0.3_450.51.06_linux.run
sudo ./cuda_11.0.3_450.51.06_linux.run --silent
echo 'export PATH=$PATH:/usr/local/cuda/bin' | sudo tee -a /etc/bash.bashrc
echo 'export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/cuda/lib64' | sudo tee -a /etc/bash.bashrc

# Install nvidia fabric manager (required for ND96asr_v4)
cd /mnt
NVIDIA_FABRIC_MNGR_URL=http://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64/nvidia-fabricmanager-450_450.80.02-1_amd64.deb
wget $NVIDIA_FABRIC_MNGR_URL
sudo apt install -y ./nvidia-fabricmanager-450_450.80.02-1_amd64.deb
sudo systemctl enable nvidia-fabricmanager
sudo systemctl start nvidia-fabricmanager

# Install NV Peer Memory (GPU Direct RDMA)
sudo apt install -y dkms libnuma-dev
cd /mnt
git clone https://github.com/Mellanox/nv_peer_memory.git
cd nv_peer_memory*/
git checkout 1_1_0_Release
./build_module.sh 
cd /mnt
mv /tmp/nvidia-peer-memory_1.1.orig.tar.gz /mnt/nvidia-peer-memory_1.1.orig.tar.gz
tar zxf /mnt/nvidia-peer-memory_1.1.orig.tar.gz
cd nvidia-peer-memory-1.1/
dpkg-buildpackage -us -uc 
sudo dpkg -i ../nvidia-peer-memory_1.1-0_all.deb 
sudo dpkg -i ../nvidia-peer-memory-dkms_1.1-0_all.deb 
sudo modprobe nv_peer_mem
lsmod | grep nv

sudo bash -c "cat > /etc/modules-load.d/nv_peer_mem.conf" <<'EOF'
nv_peer_mem
EOF

# Install gdrcopy
sudo apt install -y check libsubunit0 libsubunit-dev build-essential devscripts debhelper check libsubunit-dev fakeroot
cd /mnt
git clone https://github.com/NVIDIA/gdrcopy.git
cd gdrcopy/packages/
CUDA=/usr/local/cuda ./build-deb-packages.sh 
sudo dpkg -i gdrdrv-dkms_2.2-1_amd64.deb 
sudo dpkg -i gdrcopy_2.2-1_amd64.deb 