#!/bin/bash
set -ex

source ${COMMON_DIR}/utilities.sh


#curl https://packages.microsoft.com/azurelinux/3.0/preview/NVIDIA/x86_64/config.repo > /etc/yum.repos.d/azurelinux-nvidia-preview.repo

# Setup Azure Linux NVIDIA packages repo
curl https://packages.microsoft.com/azurelinux/3.0/prod/nvidia/x86_64/config.repo > /etc/yum.repos.d/azurelinux-nvidia-prod.repo

# Install signed NVIDIA driver
nvidia_driver_metadata=$(get_component_config "nvidia")
NVIDIA_DRIVER_VERSION=$(jq -r '.driver.version' <<< $nvidia_driver_metadata)

tdnf repolist --refresh

echo "Install CUDA GPU driver package for SKU: $1"
if [ "$1" = "V100" ]; then
    # Install Nvidia GPU propreitary variant for V100 and older SKUs
    tdnf install -y cuda
else
    # Install Nvidia GPU open source variant for A100, H100 
    tdnf install -y cuda-open
fi

$COMMON_DIR/write_component_version.sh "nvidia" $NVIDIA_DRIVER_VERSION

# Temp disable NVIDIA driver updates
mkdir -p /etc/tdnf/locks.d
echo cuda >> /etc/tdnf/locks.d/nvidia.conf

# Set the CUDA driver versions
cuda_metadata=$(get_component_config "cuda")
CUDA_DRIVER_VERSION=$(jq -r '.driver.version' <<< $cuda_metadata)
CUDA_DRIVER_DISTRIBUTION=$(jq -r '.driver.distribution' <<< $cuda_metadata)
CUDA_SAMPLES_VERSION=$(jq -r '.samples.version' <<< $cuda_metadata)
CUDA_SAMPLES_SHA256=$(jq -r '.samples.sha256' <<< $cuda_metadata)

# Install Cuda
# dnf config-manager --add-repo https://developer.download.nvidia.com/compute/cuda/repos/${CUDA_DRIVER_DISTRIBUTION}/x86_64/cuda-${CUDA_DRIVER_DISTRIBUTION}.repo
# tdnf clean expire-cache

# Install cuda-toolkit dependencies
tdnf install -y /home/packer/azhpc-images/prebuilt/nsight-systems-2024.5.1.113_3461954-1.azl3.x86_64.rpm
tdnf install -y /home/packer/azhpc-images/prebuilt/nsight-compute-2024.3.2.3_34861637-1.azl3.x86_64.rpm

# Install cuda-toolkit and sub-packages
# Till we publish to PMC repo we need to install 
# each individual package for cmdline installation
tdnf install -y /home/packer/azhpc-images/prebuilt/cuda-cccl-12.6.2_560.35.03-1.azl3.x86_64.rpm
tdnf install -y /home/packer/azhpc-images/prebuilt/cuda-cudart-12.6.2_560.35.03-1.azl3.x86_64.rpm
tdnf install -y /home/packer/azhpc-images/prebuilt/cuda-cudart-devel-12.6.2_560.35.03-1.azl3.x86_64.rpm
tdnf install -y /home/packer/azhpc-images/prebuilt/cuda-driver-devel-12.6.2_560.35.03-1.azl3.x86_64.rpm
tdnf install -y /home/packer/azhpc-images/prebuilt/cuda-nvml-devel-12.6.2_560.35.03-1.azl3.x86_64.rpm
tdnf install -y /home/packer/azhpc-images/prebuilt/cuda-nvrtc-12.6.2_560.35.03-1.azl3.x86_64.rpm
tdnf install -y /home/packer/azhpc-images/prebuilt/cuda-nvrtc-devel-12.6.2_560.35.03-1.azl3.x86_64.rpm
tdnf install -y /home/packer/azhpc-images/prebuilt/cuda-opencl-12.6.2_560.35.03-1.azl3.x86_64.rpm
tdnf install -y /home/packer/azhpc-images/prebuilt/cuda-opencl-devel-12.6.2_560.35.03-1.azl3.x86_64.rpm
tdnf install -y /home/packer/azhpc-images/prebuilt/cuda-profiler-api-12.6.2_560.35.03-1.azl3.x86_64.rpm
tdnf install -y /home/packer/azhpc-images/prebuilt/libcublas-12.6.2_560.35.03-1.azl3.x86_64.rpm
tdnf install -y /home/packer/azhpc-images/prebuilt/libcublas-devel-12.6.2_560.35.03-1.azl3.x86_64.rpm
tdnf install -y /home/packer/azhpc-images/prebuilt/libcufft-12.6.2_560.35.03-1.azl3.x86_64.rpm
tdnf install -y /home/packer/azhpc-images/prebuilt/libcufft-devel-12.6.2_560.35.03-1.azl3.x86_64.rpm
tdnf install -y /home/packer/azhpc-images/prebuilt/libcufile-12.6.2_560.35.03-1.azl3.x86_64.rpm
tdnf install -y /home/packer/azhpc-images/prebuilt/libcufile-devel-12.6.2_560.35.03-1.azl3.x86_64.rpm
tdnf install -y /home/packer/azhpc-images/prebuilt/libcurand-12.6.2_560.35.03-1.azl3.x86_64.rpm
tdnf install -y /home/packer/azhpc-images/prebuilt/libcurand-devel-12.6.2_560.35.03-1.azl3.x86_64.rpm
tdnf install -y /home/packer/azhpc-images/prebuilt/libnvfatbin-12.6.2_560.35.03-1.azl3.x86_64.rpm
tdnf install -y /home/packer/azhpc-images/prebuilt/libnvfatbin-devel-12.6.2_560.35.03-1.azl3.x86_64.rpm
tdnf install -y /home/packer/azhpc-images/prebuilt/libnvjitlink-12.6.2_560.35.03-1.azl3.x86_64.rpm
tdnf install -y /home/packer/azhpc-images/prebuilt/libnvjitlink-devel-12.6.2_560.35.03-1.azl3.x86_64.rpm
tdnf install -y /home/packer/azhpc-images/prebuilt/libnvjpeg-12.6.2_560.35.03-1.azl3.x86_64.rpm
tdnf install -y /home/packer/azhpc-images/prebuilt/libnvjpeg-devel-12.6.2_560.35.03-1.azl3.x86_64.rpm
tdnf install -y /home/packer/azhpc-images/prebuilt/libcusparse-12.6.2_560.35.03-1.azl3.x86_64.rpm
tdnf install -y /home/packer/azhpc-images/prebuilt/libcusparse-devel-12.6.2_560.35.03-1.azl3.x86_64.rpm
tdnf install -y /home/packer/azhpc-images/prebuilt/libcusolver-12.6.2_560.35.03-1.azl3.x86_64.rpm
tdnf install -y /home/packer/azhpc-images/prebuilt/libcusolver-devel-12.6.2_560.35.03-1.azl3.x86_64.rpm
tdnf install -y /home/packer/azhpc-images/prebuilt/libnpp-12.6.2_560.35.03-1.azl3.x86_64.rpm
tdnf install -y /home/packer/azhpc-images/prebuilt/libnpp-devel-12.6.2_560.35.03-1.azl3.x86_64.rpm
tdnf install -y /home/packer/azhpc-images/prebuilt/cuda-cupti-12.6.2_560.35.03-1.azl3.x86_64.rpm
tdnf install -y /home/packer/azhpc-images/prebuilt/cuda-nvdisasm-12.6.2_560.35.03-1.azl3.x86_64.rpm
tdnf install -y /home/packer/azhpc-images/prebuilt/cuda-nvprof-12.6.2_560.35.03-1.azl3.x86_64.rpm
tdnf install -y /home/packer/azhpc-images/prebuilt/cuda-nvtx-12.6.2_560.35.03-1.azl3.x86_64.rpm
tdnf install -y /home/packer/azhpc-images/prebuilt/cuda-nsight-12.6.2_560.35.03-1.azl3.x86_64.rpm
tdnf install -y /home/packer/azhpc-images/prebuilt/cuda-nvvp-12.6.2_560.35.03-1.azl3.x86_64.rpm
tdnf install -y /home/packer/azhpc-images/prebuilt/cuda-nsight-systems-12.6.2_560.35.03-1.azl3.x86_64.rpm
tdnf install -y /home/packer/azhpc-images/prebuilt/cuda-nsight-compute-12.6.2_560.35.03-1.azl3.x86_64.rpm
tdnf install -y /home/packer/azhpc-images/prebuilt/cuda-cuobjdump-12.6.2_560.35.03-1.azl3.x86_64.rpm
tdnf install -y /home/packer/azhpc-images/prebuilt/cuda-cuxxfilt-12.6.2_560.35.03-1.azl3.x86_64.rpm
tdnf install -y /home/packer/azhpc-images/prebuilt/cuda-nvcc-12.6.2_560.35.03-1.azl3.x86_64.rpm
tdnf install -y /home/packer/azhpc-images/prebuilt/cuda-nvvm-12.6.2_560.35.03-1.azl3.x86_64.rpm
tdnf install -y /home/packer/azhpc-images/prebuilt/cuda-crt-12.6.2_560.35.03-1.azl3.x86_64.rpm
tdnf install -y /home/packer/azhpc-images/prebuilt/cuda-nvprune-12.6.2_560.35.03-1.azl3.x86_64.rpm
tdnf install -y /home/packer/azhpc-images/prebuilt/cuda-documentation-12.6.2_560.35.03-1.azl3.x86_64.rpm
tdnf install -y /home/packer/azhpc-images/prebuilt/gds-tools-12.6.2_560.35.03-1.azl3.x86_64.rpm

tdnf install -y /home/packer/azhpc-images/prebuilt/cuda-toolkit-12.6.2_560.35.03-1.azl3.x86_64.rpm

echo 'export PATH=$PATH:/usr/local/cuda/bin' | tee -a /etc/bash.bashrc
echo 'export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/cuda/lib64' | tee -a /etc/bash.bashrc
$COMMON_DIR/write_component_version.sh "CUDA" ${CUDA_DRIVER_VERSION}

# Download CUDA samples
TARBALL="v${CUDA_SAMPLES_VERSION}.tar.gz"
CUDA_SAMPLES_DOWNLOAD_URL=https://github.com/NVIDIA/cuda-samples/archive/refs/tags/${TARBALL}
# $COMMON_DIR/download_and_verify.sh $CUDA_SAMPLES_DOWNLOAD_URL $CUDA_SAMPLES_SHA256
cp /home/packer/azhpc-images/prebuilt/${TARBALL} .
tar -xvf ${TARBALL}
pushd ./cuda-samples-${CUDA_SAMPLES_VERSION}
make -j $(nproc)
mkdir -p /usr/local/cuda-${CUDA_SAMPLES_VERSION}
mv -vT ./Samples /usr/local/cuda-${CUDA_SAMPLES_VERSION}/samples
popd

# Temporarily install NV Peer Memory
# $AZURE_LINUX_COMMON_DIR/install_nv_peer_memory.sh

# load the nvidia-peermem coming as a part of NVIDIA GPU driver
# modprobe nvidia_peermem
# verify if loaded
# lsmod | grep nvidia_peermem

touch /etc/modules-load.d/nvidia-peermem.conf
echo "nvidia_peermem" >> /etc/modules-load.d/nvidia-peermem.conf

# Install GDRCopy
$AZURE_LINUX_COMMON_DIR/install_gdrcopy.sh

# Install nvidia fabric manager (required for ND96asr_v4)
$AZURE_LINUX_COMMON_DIR/install_nvidia_fabric_manager.sh

# Install libnvidia-nscq
tdnf install -y libnvidia-nscq

# cleanup downloaded files
rm -rf *.run *tar.gz *.rpm
rm -rf -- */
