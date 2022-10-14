#!/bin/bash
set -ex

# Install Cuda
NVIDIA_VERSION="510.85.02"
CUDA_VERSION="11-6"
dnf config-manager --add-repo https://developer.download.nvidia.com/compute/cuda/repos/rhel8/x86_64/cuda-rhel8.repo
dnf clean expire-cache
dnf install cuda-toolkit-11-6 -y
echo 'export PATH=$PATH:/usr/local/cuda/bin' | tee -a /etc/bash.bashrc
echo 'export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/cuda/lib64' | tee -a /etc/bash.bashrc
$COMMON_DIR/write_component_version.sh "CUDA" ${CUDA_VERSION}

# Download CUDA samples
CUDA_SAMPLES_VERSION="11.6"
TARBALL="v${CUDA_SAMPLES_VERSION}.tar.gz"
CUDA_SAMPLES_DOWNLOAD_URL=https://github.com/NVIDIA/cuda-samples/archive/refs/tags/${TARBALL}
wget ${CUDA_SAMPLES_DOWNLOAD_URL}
tar -xvf ${TARBALL}
pushd ./cuda-samples-${CUDA_SAMPLES_VERSION}
make -j $(nproc)
cp -r ./Samples/* /usr/local/cuda-11.6/samples/
popd

# Nvidia driver
NVIDIA_DRIVER_URL=https://us.download.nvidia.com/tesla/${NVIDIA_VERSION}/NVIDIA-Linux-x86_64-${NVIDIA_VERSION}.run
$COMMON_DIR/download_and_verify.sh $NVIDIA_DRIVER_URL "372427e633f32cff6dd76020e8ed471ef825d38878bd9655308b6efea1051090"
bash NVIDIA-Linux-x86_64-${NVIDIA_VERSION}.run --silent --dkms
$COMMON_DIR/write_component_version.sh "NVIDIA" ${NVIDIA_VERSION}

# Install NV Peer Memory (GPU Direct RDMA)
NV_PEER_MEMORY_VERSION="1.3-0"
TARBALL="${NV_PEER_MEMORY_VERSION}.tar.gz"
NV_PEER_MEMORY_DOWNLOAD_URL=https://github.com/Mellanox/nv_peer_memory/archive/refs/tags/${TARBALL}
wget ${NV_PEER_MEMORY_DOWNLOAD_URL}
tar -xvf ${TARBALL}
pushd ./nv_peer_memory-${NV_PEER_MEMORY_VERSION}
yum install -y rpm-build
./build_module.sh 
rpmbuild --rebuild /tmp/nvidia_peer_memory-${NV_PEER_MEMORY_VERSION}.src.rpm
rpm -ivh ~/rpmbuild/RPMS/x86_64/nvidia_peer_memory-${NV_PEER_MEMORY_VERSION}.x86_64.rpm
echo "exclude=nvidia_peer_memory" | tee -a /etc/yum.conf
popd

# load the nvidia-peermem coming as a part of NVIDIA GPU driver
# Reference - https://download.nvidia.com/XFree86/Linux-x86_64/510.85.02/README/nvidia-peermem.html
# Stop nv_peer_mem service
service nv_peer_mem stop
# load nvidia-peermem
modprobe nvidia-peermem
# verify if loaded
lsmod | grep nvidia_peermem

$COMMON_DIR/write_component_version.sh "NV_PEER_MEMORY" ${NV_PEER_MEMORY_VERSION}

# Install GDRCopy
GDRCOPY_VERSION="2.3"
TARBALL="v${GDRCOPY_VERSION}.tar.gz"
GDRCOPY_DOWNLOAD_URL=https://github.com/NVIDIA/gdrcopy/archive/refs/tags/${TARBALL}
wget $GDRCOPY_DOWNLOAD_URL
tar -xvf $TARBALL

pushd gdrcopy-${GDRCOPY_VERSION}/packages/
CUDA=/usr/local/cuda ./build-rpm-packages.sh
rpm -Uvh gdrcopy-kmod-${GDRCOPY_VERSION}-1dkms.noarch.el8.rpm
echo "exclude=gdrcopy-kmod.noarch" | tee -a /etc/yum.conf
rpm -Uvh gdrcopy-${GDRCOPY_VERSION}-1.x86_64.el8.rpm
echo "exclude=gdrcopy" | tee -a /etc/yum.conf
rpm -Uvh gdrcopy-devel-${GDRCOPY_VERSION}-1.noarch.el8.rpm
echo "exclude=gdrcopy-devel.noarch" | tee -a /etc/yum.conf
popd

$COMMON_DIR/write_component_version.sh "GDRCOPY" ${GDRCOPY_VERSION}

# Install Fabric Manager
NVIDIA_FABRIC_MANAGER_VERSION="510.85.02-1"
NVIDIA_FABRIC_MNGR_URL=http://developer.download.nvidia.com/compute/cuda/repos/rhel8/x86_64/nvidia-fabric-manager-${NVIDIA_FABRIC_MANAGER_VERSION}.x86_64.rpm
$COMMON_DIR/download_and_verify.sh ${NVIDIA_FABRIC_MNGR_URL} "7f8468e92deb78e427df8b4947c4b0fd7a7b5eedf1e3961e60436b4620b2fa1d"
yum install -y ./nvidia-fabric-manager-${NVIDIA_FABRIC_MANAGER_VERSION}.x86_64.rpm
echo "exclude=nvidia-fabric-manager" | tee -a /etc/yum.conf
$COMMON_DIR/write_component_version.sh "NVIDIA_FABRIC_MANAGER" ${NVIDIA_FABRIC_MANAGER_VERSION}

# cleanup downloaded files
rm -rf *.run *tar.gz *.rpm
rm -rf -- */
