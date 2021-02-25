#!/bin/bash

# Enable RDMA in waagent
sudo sed -i -e 's/# OS.EnableRDMA=y/OS.EnableRDMA=y/g' /etc/waagent.conf
echo "Extensions.GoalStatePeriod=300" | sudo tee -a /etc/waagent.conf
echo "OS.EnableFirewallPeriod=300" | sudo tee -a /etc/waagent.conf
echo "OS.RemovePersistentNetRulesPeriod=300" | sudo tee -a /etc/waagent.conf
echo "OS.RootDeviceScsiTimeoutPeriod=300" | sudo tee -a /etc/waagent.conf
echo "OS.MonitorDhcpClientRestartPeriod=60" | sudo tee -a /etc/waagent.conf
echo "Provisioning.MonitorHostNamePeriod=60" | sudo tee -a /etc/waagent.conf
sudo systemctl restart walinuxagent

# Nvidia driver
cd /mnt
NVIDIA_DRIVER_URL=https://us.download.nvidia.com/XFree86/Linux-x86_64/450.80.02/NVIDIA-Linux-x86_64-450.80.02.run
$COMMON_DIR/download_and_verify.sh $NVIDIA_DRIVER_URL "0f5a2f19f822d46c54500f4a6192dad9948821ed14ce7c13b38264d67aaf95b3"
chmod 755 NVIDIA-Linux-x86_64-450.80.02.run
sudo ./NVIDIA-Linux-x86_64-450.80.02.run -s

# Install DCGM
DCGM_VERSION=2.0.10
DCGM_GPUMNGR_URL=https://developer.download.nvidia.com/compute/redist/dcgm/${DCGM_VERSION}/DEBS/datacenter-gpu-manager_${DCGM_VERSION}_amd64.deb
$COMMON_DIR/download_and_verify.sh $DCGM_GPUMNGR_URL "c32f2758611cc4e4e2ae69372a350bf14733d92b9cb5963ada9df0ee0aa63b76"
sudo dpkg -i datacenter-gpu-manager_*.deb && \
sudo rm -f datacenter-gpu-manager_*.deb

# Create service for dcgm to launch on bootup
sudo bash -c "cat > /etc/systemd/system/dcgm.service" <<'EOF'
[Unit]
Description=DCGM service

[Service]
User=root
PrivateTmp=false
ExecStart=/usr/bin/nv-hostengine -n
Restart=on-abort

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable dcgm
sudo systemctl start dcgm

# Install nvidia fabric manager (required for ND96asr_v4)
cd /mnt
NVIDIA_FABRIC_MNGR_URL=http://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64/nvidia-fabricmanager-450_450.80.02-1_amd64.deb
$COMMON_DIR/download_and_verify.sh $NVIDIA_FABRIC_MNGR_URL "4f14f162ad40e0824695f7489e27b24cf762b733ffcb0f30f084a228659594bf"
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
cd ../tests/
make
sanity 
copybw
copylat