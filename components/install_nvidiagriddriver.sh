#!/bin/bash
set -ex

# GRID/vGPU driver install for NCv6.
# Differences vs install_nvidiagpudriver.sh
#   - GRID driver from Microsoft instead of Tesla driver from NVIDIA
#   - No nvidia-peermem (no InfiniBand)
#   - No GDRCopy (BAR1 mapping fails under vGPU and no RDMA to support)
#   - No NVIDIA Fabric Manager (no NVSwitch/NVLink fabric)

source ${UTILS_DIR}/utilities.sh

# Retrieve GRID driver metadata from versions.json
grid_metadata=$(get_component_config "nvidia_grid")
GRID_DRIVER_URL=$(jq -r '.url' <<< $grid_metadata)
GRID_DRIVER_SHA256=$(jq -r '.sha256' <<< $grid_metadata)
GRID_DRIVER_VERSION=$(jq -r '.version' <<< $grid_metadata)

# Download the GRID driver
download_and_verify $GRID_DRIVER_URL $GRID_DRIVER_SHA256

bash NVIDIA-Linux-x86_64-${GRID_DRIVER_VERSION}-grid-azure.run --silent --dkms --kernel-module-type=open

write_component_version "NVIDIA_GRID" ${GRID_DRIVER_VERSION}

# Configure GRID licensing
cp /etc/nvidia/gridd.conf.template /etc/nvidia/gridd.conf
# Ensure required settings are present and remove FeatureType=0 if present (per Azure documentation)
grep -q '^IgnoreSP=' /etc/nvidia/gridd.conf && sed -i 's/^IgnoreSP=.*/IgnoreSP=FALSE/' /etc/nvidia/gridd.conf || echo 'IgnoreSP=FALSE' >> /etc/nvidia/gridd.conf
grep -q '^EnableUI=' /etc/nvidia/gridd.conf && sed -i 's/^EnableUI=.*/EnableUI=FALSE/' /etc/nvidia/gridd.conf || echo 'EnableUI=FALSE' >> /etc/nvidia/gridd.conf
sed -i '/^FeatureType=0/d' /etc/nvidia/gridd.conf

# Install CUDA toolkit
cuda_metadata=$(get_component_config "cuda")
CUDA_DRIVER_VERSION=$(jq -r '.driver.version' <<< $cuda_metadata)
CUDA_DRIVER_DISTRIBUTION=$(jq -r '.driver.distribution' <<< $cuda_metadata)
# Add NVIDIA CUDA APT repo (provides toolkit packages)
wget https://developer.download.nvidia.com/compute/cuda/repos/${CUDA_DRIVER_DISTRIBUTION}/x86_64/cuda-keyring_1.1-1_all.deb
dpkg -i ./cuda-keyring_1.1-1_all.deb
apt-get update
apt install -y cuda-toolkit-${CUDA_DRIVER_VERSION//./-}

echo 'export PATH=$PATH:/usr/local/cuda/bin' | tee /etc/profile.d/cuda.sh > /dev/null
echo 'export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/cuda/lib64' | tee -a /etc/profile.d/cuda.sh > /dev/null
chmod 644 /etc/profile.d/cuda.sh

cuda_version=$(source /etc/profile; nvcc --version | grep release | awk '{print $6}' | cut -c2-)
write_component_version "CUDA" ${cuda_version}

$COMPONENT_DIR/install_cuda_samples.sh
$COMPONENT_DIR/configure_nvidia_persistence.sh

# cleanup downloaded files
rm -rf *.run *.tar.gz *.rpm
rm -rf -- */
