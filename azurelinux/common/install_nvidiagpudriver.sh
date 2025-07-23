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

kernel_version=$(uname -r | sed 's/\-/./g')


echo "Install CUDA GPU driver package for SKU: $1"
if [ "$1" = "V100" ]; then
    # Install Nvidia GPU propreitary variant for V100 and older SKUs
    tdnf install -y cuda-$NVIDIA_DRIVER_VERSION-1_$kernel_version.x86_64
else
    # Install Nvidia GPU open source variant for A100, H100 
    tdnf install -y cuda-open-$NVIDIA_DRIVER_VERSION-1_$kernel_version.x86_64
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
tdnf install -y $TOP_DIR/prebuilt/nsight-systems-2025.2.1.130_3569061-1.azl3.x86_64.rpm
tdnf install -y $TOP_DIR/prebuilt/nsight-compute-2025.1.1.2_35528883-1.azl3.x86_64.rpm

# Install cuda-toolkit and sub-packages
# Till we publish to PMC repo we need to install 
# each individual package for cmdline installation

path_var="$TOP_DIR/prebuilt"
version_var="-12.8.1_570.124.06-1.azl3"

tdnf install -y $path_var/cuda-cccl$version_var.x86_64.rpm
tdnf install -y $path_var/cuda-cudart$version_var.x86_64.rpm
tdnf install -y $path_var/cuda-cudart-devel$version_var.x86_64.rpm
tdnf install -y $path_var/cuda-driver-devel$version_var.x86_64.rpm
tdnf install -y $path_var/cuda-nvml-devel$version_var.x86_64.rpm
tdnf install -y $path_var/cuda-nvrtc$version_var.x86_64.rpm
tdnf install -y $path_var/cuda-nvrtc-devel$version_var.x86_64.rpm
tdnf install -y $path_var/cuda-opencl$version_var.x86_64.rpm
tdnf install -y $path_var/cuda-opencl-devel$version_var.x86_64.rpm
tdnf install -y $path_var/cuda-profiler-api$version_var.x86_64.rpm
tdnf install -y $path_var/libcublas$version_var.x86_64.rpm
tdnf install -y $path_var/libcublas-devel$version_var.x86_64.rpm
tdnf install -y $path_var/libcufft$version_var.x86_64.rpm
tdnf install -y $path_var/libcufft-devel$version_var.x86_64.rpm
tdnf install -y $path_var/libcufile$version_var.x86_64.rpm
tdnf install -y $path_var/libcufile-devel$version_var.x86_64.rpm
tdnf install -y $path_var/libcurand$version_var.x86_64.rpm
tdnf install -y $path_var/libcurand-devel$version_var.x86_64.rpm
tdnf install -y $path_var/libnvfatbin$version_var.x86_64.rpm
tdnf install -y $path_var/libnvfatbin-devel$version_var.x86_64.rpm
tdnf install -y $path_var/libnvjitlink$version_var.x86_64.rpm
tdnf install -y $path_var/libnvjitlink-devel$version_var.x86_64.rpm
tdnf install -y $path_var/libnvjpeg$version_var.x86_64.rpm
tdnf install -y $path_var/libnvjpeg-devel$version_var.x86_64.rpm
tdnf install -y $path_var/libcusparse$version_var.x86_64.rpm
tdnf install -y $path_var/libcusparse-devel$version_var.x86_64.rpm
tdnf install -y $path_var/libcusolver$version_var.x86_64.rpm
tdnf install -y $path_var/libcusolver-devel$version_var.x86_64.rpm
tdnf install -y $path_var/libnpp$version_var.x86_64.rpm
tdnf install -y $path_var/libnpp-devel$version_var.x86_64.rpm
tdnf install -y $path_var/cuda-cupti$version_var.x86_64.rpm
tdnf install -y $path_var/cuda-nvdisasm$version_var.x86_64.rpm
tdnf install -y $path_var/cuda-nvprof$version_var.x86_64.rpm
tdnf install -y $path_var/cuda-nvtx$version_var.x86_64.rpm
tdnf install -y $path_var/cuda-nsight$version_var.x86_64.rpm
tdnf install -y $path_var/cuda-nvvp$version_var.x86_64.rpm
tdnf install -y $path_var/cuda-nsight-systems$version_var.x86_64.rpm
tdnf install -y $path_var/cuda-nsight-compute$version_var.x86_64.rpm
tdnf install -y $path_var/cuda-cuobjdump$version_var.x86_64.rpm
tdnf install -y $path_var/cuda-cuxxfilt$version_var.x86_64.rpm
tdnf install -y $path_var/cuda-nvcc$version_var.x86_64.rpm
tdnf install -y $path_var/cuda-nvvm$version_var.x86_64.rpm
tdnf install -y $path_var/cuda-crt$version_var.x86_64.rpm
tdnf install -y $path_var/cuda-nvprune$version_var.x86_64.rpm
tdnf install -y $path_var/cuda-documentation$version_var.x86_64.rpm
tdnf install -y $path_var/gds-tools$version_var.x86_64.rpm

tdnf install -y $path_var/cuda-toolkit$version_var.x86_64.rpm

echo 'export PATH=$PATH:/usr/local/cuda/bin' | tee -a /etc/bash.bashrc
echo 'export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/cuda/lib64' | tee -a /etc/bash.bashrc
$COMMON_DIR/write_component_version.sh "CUDA" ${CUDA_DRIVER_VERSION}

# Download CUDA samples
TARBALL="v${CUDA_SAMPLES_VERSION}.tar.gz"
CUDA_SAMPLES_DOWNLOAD_URL=https://github.com/NVIDIA/cuda-samples/archive/refs/tags/${TARBALL}
# $COMMON_DIR/download_and_verify.sh $CUDA_SAMPLES_DOWNLOAD_URL $CUDA_SAMPLES_SHA256
cp $TOP_DIR/prebuilt/${TARBALL} .
tar -xvf ${TARBALL}
pushd ./cuda-samples-${CUDA_SAMPLES_VERSION}
mkdir build && cd build
cmake -DCMAKE_CUDA_COMPILER=/usr/local/cuda/bin/nvcc ..
make -j $(nproc)
mv -vT ./Samples /usr/local/cuda-${CUDA_DRIVER_VERSION}/samples # Use the same version as the CUDA toolkit as thats where samples is being moved to
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
