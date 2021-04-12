#!/bin/bash
set -ex

# Install Cuda
CUDA_URL=https://developer.download.nvidia.com/compute/cuda/11.2.2/local_installers/cuda_11.2.2_460.32.03_linux.run
$COMMON_DIR/download_and_verify.sh $CUDA_URL "0a2e477224af7f6003b49edfd2bfee07667a8148fe3627cfd2765f6ad72fa19d"
chmod +x cuda_11.2.2_460.32.03_linux.run
sh cuda_11.2.2_460.32.03_linux.run --silent --driver --toolkit
echo 'export PATH=$PATH:/usr/local/cuda/bin' | sudo tee -a /etc/bash.bashrc
echo 'export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/cuda/lib64' | sudo tee -a /etc/bash.bashrc

# Nvidia driver
NVIDIA_DRIVER_URL=https://download.nvidia.com/XFree86/Linux-x86_64/460.32.03/NVIDIA-Linux-x86_64-460.32.03.run
$COMMON_DIR/download_and_verify.sh $NVIDIA_DRIVER_URL "4f2122fc23655439f214717c4c35ab9b4f5ab8537cddfdf059a5682f1b726061"
bash NVIDIA-Linux-x86_64-460.32.03.run --silent

# Install NV Peer Memory (GPU Direct RDMA)
git clone https://github.com/Mellanox/nv_peer_memory.git
pushd nv_peer_memory
git checkout 1_1_0_Release
./build_module.sh 
rpmbuild --rebuild /tmp/nvidia_peer_memory-1.1-0.src.rpm
rpm -ivh ~/rpmbuild/RPMS/x86_64/nvidia_peer_memory-1.1-0.x86_64.rpm
sudo modprobe nv_peer_mem
lsmod | grep nv
popd

sudo bash -c "cat > /etc/modules-load.d/nv_peer_mem.conf" <<'EOF'
nv_peer_mem
EOF

sudo systemctl enable nv_peer_mem.service

# Install GDRCopy
yum install -y https://dl.fedoraproject.org/pub/epel/7/x86_64/Packages/s/subunit-0.0.21-2.el7.x86_64.rpm
yum install -y https://dl.fedoraproject.org/pub/epel/7/x86_64/Packages/s/subunit-devel-0.0.21-2.el7.x86_64.rpm
yum install -y https://dl.fedoraproject.org/pub/epel/7/x86_64/Packages/d/dkms-2.8.4-1.el7.noarch.rpm
yum install -y rpm-build make check check-devel 
git clone https://github.com/NVIDIA/gdrcopy.git
pushd gdrcopy/packages/
CUDA=/usr/local/cuda ./build-rpm-packages.sh
rpm -Uvh gdrcopy-kmod-2.2-1dkms.noarch.rpm
rpm -Uvh gdrcopy-2.2-1.x86_64.rpm
rpm -Uvh gdrcopy-devel-2.2-1.noarch.rpm
popd

# Install Fabric Manager
NVIDIA_FABRIC_MNGR_URL=http://developer.download.nvidia.com/compute/cuda/repos/rhel7/x86_64/nvidia-fabricmanager-460-460.32.03-1.x86_64.rpm
$COMMON_DIR/download_and_verify.sh $NVIDIA_FABRIC_MNGR_URL "6801295b4d7d08682d7cc56b403139214f366dd65646824fed63be72294eb464"
yum install -y ./nvidia-fabricmanager-460-460.32.03-1.x86_64.rpm
systemctl enable nvidia-fabricmanager
systemctl start nvidia-fabricmanager
