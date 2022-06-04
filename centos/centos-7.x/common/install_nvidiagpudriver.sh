#!/bin/bash
set -ex

$COMMON_DIR/install_nvidiagpudriver.sh

# Install NV Peer Memory (GPU Direct RDMA)
NV_PEER_MEMORY_VERSION="1.2-0"
$COMMON_DIR/write_component_version.sh "NV_PEER_MEMORY" ${NV_PEER_MEMORY_VERSION}
git clone https://github.com/gpudirect/nv_peer_memory.git

pushd nv_peer_memory
yum install -y rpm-build
./build_module.sh 
rpmbuild --rebuild /tmp/nvidia_peer_memory-${NV_PEER_MEMORY_VERSION}.src.rpm
rpm -ivh ~/rpmbuild/RPMS/x86_64/nvidia_peer_memory-${NV_PEER_MEMORY_VERSION}.x86_64.rpm
echo "exclude=nvidia_peer_memory" | sudo tee -a /etc/yum.conf
sudo modprobe nv_peer_mem
lsmod | grep nv
popd

sudo bash -c "cat > /etc/modules-load.d/nv_peer_mem.conf" <<'EOF'
nv_peer_mem
EOF

sudo systemctl enable nv_peer_mem.service

# Install GDRCopy
GDRCOPY_VERSION="2.3"
$COMMON_DIR/write_component_version.sh "GDRCOPY" ${GDRCOPY_VERSION}
TARBALL="v${GDRCOPY_VERSION}.tar.gz"
GDRCOPY_DOWNLOAD_URL=https://github.com/NVIDIA/gdrcopy/archive/refs/tags/${TARBALL}
wget $GDRCOPY_DOWNLOAD_URL
tar -xvf $TARBALL

pushd gdrcopy-${GDRCOPY_VERSION}/packages/
CUDA=/usr/local/cuda ./build-rpm-packages.sh
rpm -Uvh gdrcopy-kmod-${GDRCOPY_VERSION}-1dkms.noarch.el7.rpm
echo "exclude=gdrcopy-kmod.noarch" | sudo tee -a /etc/yum.conf
rpm -Uvh gdrcopy-${GDRCOPY_VERSION}-1.x86_64.el7.rpm
echo "exclude=gdrcopy" | sudo tee -a /etc/yum.conf
rpm -Uvh gdrcopy-devel-${GDRCOPY_VERSION}-1.noarch.el7.rpm
echo "exclude=gdrcopy-devel.noarch" | sudo tee -a /etc/yum.conf
popd

# Install Fabric Manager
NVIDIA_FABRIC_MANAGER_VERSION="470.82.01-1"
$COMMON_DIR/write_component_version.sh "NVIDIA_FABRIC_MANAGER" ${NVIDIA_FABRIC_MANAGER_VERSION}
NVIDIA_FABRIC_MNGR_URL=http://developer.download.nvidia.com/compute/cuda/repos/rhel7/x86_64/nvidia-fabric-manager-${NVIDIA_FABRIC_MANAGER_VERSION}.x86_64.rpm
$COMMON_DIR/download_and_verify.sh ${NVIDIA_FABRIC_MNGR_URL} "ade1051a189fe84a326b8021d1446eb03d48e0a998e8cada85081b27a89923f1"
yum install -y ./nvidia-fabric-manager-${NVIDIA_FABRIC_MANAGER_VERSION}.x86_64.rpm
echo "exclude=nvidia-fabric-manager" | sudo tee -a /etc/yum.conf
systemctl enable nvidia-fabricmanager
systemctl start nvidia-fabricmanager
