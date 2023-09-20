#!/bin/bash
set -ex

case ${DISTRIBUTION} in
    "almalinux8.6") NVIDIA_VERSION="510.85.02"; 
        CUDA_VERSION="11-6"; 
        CUDA_SAMPLES_VERSION="11.6";
        NVIDIA_DRIVER_CHECKSUM="372427e633f32cff6dd76020e8ed471ef825d38878bd9655308b6efea1051090";
        NVIDIA_FABRIC_MANAGER_VERSION="510.85.02-1";
        NVIDIA_FABRIC_MANAGER_CHECKSUM="7f8468e92deb78e427df8b4947c4b0fd7a7b5eedf1e3961e60436b4620b2fa1d";
        ;;
    "almalinux8.7") NVIDIA_VERSION="525.105.17"; 
        CUDA_VERSION="12-1"; 
        CUDA_SAMPLES_VERSION="12.1";
        NVIDIA_DRIVER_CHECKSUM="c635a21a282c9b53485f19ebb64a0f4b536a968b94d4d97629e0bc547a58142a";
        NVIDIA_FABRIC_MANAGER_VERSION="525.105.17-1";
        NVIDIA_FABRIC_MANAGER_CHECKSUM="4d6a11cbaa2aa278ef3fc9818c77f0f9fdf10e54d0d15b607b5beaae90b119ec";
        ;;
    *) ;;
esac

# Install Cuda
dnf config-manager --add-repo https://developer.download.nvidia.com/compute/cuda/repos/rhel8/x86_64/cuda-rhel8.repo
dnf clean expire-cache
dnf install cuda-toolkit-${CUDA_VERSION} -y
echo 'export PATH=$PATH:/usr/local/cuda/bin' | tee -a /etc/bash.bashrc
echo 'export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/cuda/lib64' | tee -a /etc/bash.bashrc
$COMMON_DIR/write_component_version.sh "CUDA" ${CUDA_VERSION}

# Download CUDA samples
TARBALL="v${CUDA_SAMPLES_VERSION}.tar.gz"
CUDA_SAMPLES_DOWNLOAD_URL=https://github.com/NVIDIA/cuda-samples/archive/refs/tags/${TARBALL}
wget ${CUDA_SAMPLES_DOWNLOAD_URL}
tar -xvf ${TARBALL}
pushd ./cuda-samples-${CUDA_SAMPLES_VERSION}
make -j $(nproc)
mv -vT ./Samples /usr/local/cuda-${CUDA_SAMPLES_VERSION}/samples
popd

# Nvidia driver
NVIDIA_DRIVER_URL=https://us.download.nvidia.com/tesla/${NVIDIA_VERSION}/NVIDIA-Linux-x86_64-${NVIDIA_VERSION}.run
$COMMON_DIR/download_and_verify.sh $NVIDIA_DRIVER_URL ${NVIDIA_DRIVER_CHECKSUM}
bash NVIDIA-Linux-x86_64-${NVIDIA_VERSION}.run --silent --dkms
dkms install --no-depmod -m nvidia -v ${NVIDIA_VERSION} -k `uname -r` --force
$COMMON_DIR/write_component_version.sh "NVIDIA" ${NVIDIA_VERSION}

# load the nvidia-peermem coming as a part of NVIDIA GPU driver
# Reference - https://download.nvidia.com/XFree86/Linux-x86_64/510.85.02/README/nvidia-peermem.html
modprobe nvidia-peermem
# verify if loaded
lsmod | grep nvidia_peermem

# Install GDRCopy
GDRCOPY_VERSION="2.3"
TARBALL="v${GDRCOPY_VERSION}.tar.gz"
GDRCOPY_DOWNLOAD_URL=https://github.com/NVIDIA/gdrcopy/archive/refs/tags/${TARBALL}
wget $GDRCOPY_DOWNLOAD_URL
tar -xvf $TARBALL

pushd gdrcopy-${GDRCOPY_VERSION}/packages/
CUDA=/usr/local/cuda ./build-rpm-packages.sh
rpm -Uvh gdrcopy-kmod-${GDRCOPY_VERSION}-1dkms.noarch.el8.rpm
rpm -Uvh gdrcopy-${GDRCOPY_VERSION}-1.x86_64.el8.rpm
rpm -Uvh gdrcopy-devel-${GDRCOPY_VERSION}-1.noarch.el8.rpm
sed -i "$ s/$/ gdrcopy*/" /etc/dnf/dnf.conf
popd

$COMMON_DIR/write_component_version.sh "GDRCOPY" ${GDRCOPY_VERSION}

# Install Fabric Manager
NVIDIA_FABRIC_MNGR_URL=http://developer.download.nvidia.com/compute/cuda/repos/rhel8/x86_64/nvidia-fabric-manager-${NVIDIA_FABRIC_MANAGER_VERSION}.x86_64.rpm
$COMMON_DIR/download_and_verify.sh ${NVIDIA_FABRIC_MNGR_URL} ${NVIDIA_FABRIC_MANAGER_CHECKSUM}
yum install -y ./nvidia-fabric-manager-${NVIDIA_FABRIC_MANAGER_VERSION}.x86_64.rpm
sed -i "$ s/$/ nvidia-fabric-manager/" /etc/dnf/dnf.conf
$COMMON_DIR/write_component_version.sh "NVIDIA_FABRIC_MANAGER" ${NVIDIA_FABRIC_MANAGER_VERSION}

# cleanup downloaded files
rm -rf *.run *tar.gz *.rpm
rm -rf -- */
