#!/bin/bash
set -ex

source ${UTILS_DIR}/utilities.sh

# TODO: The GRID driver URL is hardcoded for the initial implementation.
# Once we lock down how the official GRID driver URL scheme will work long-term,
# generalize this to derive the URL from versions.json.
GRID_DRIVER_URL="https://download.microsoft.com/download/85beffdc-8361-4df4-a823-dcb1b230a7aa/NVIDIA-Linux-x86_64-580.105.08-grid-azure.run"
GRID_DRIVER_SHA256="b360c7edf0686c7e47b1dc7980baa5c7740a00eb372cfafe045a28b4456fb32b"
GRID_DRIVER_VERSION="580.105.08"

# Download the GRID driver
download_and_verify $GRID_DRIVER_URL $GRID_DRIVER_SHA256

bash NVIDIA-Linux-x86_64-580.105.08-grid-azure.run --silent --dkms --kernel-module-type=open

write_component_version "NVIDIA_GRID" "580.105.08"

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
# Dependency for nvidia driver installation
apt-get install -y libvulkan1
# Reference - https://docs.nvidia.com/cuda/cuda-installation-guide-linux/index.html#ubuntu-installation
wget https://developer.download.nvidia.com/compute/cuda/repos/${CUDA_DRIVER_DISTRIBUTION}/x86_64/cuda-keyring_1.1-1_all.deb
dpkg -i ./cuda-keyring_1.1-1_all.deb
apt-get update
apt install -y cuda-toolkit-${CUDA_DRIVER_VERSION//./-}

echo 'export PATH=$PATH:/usr/local/cuda/bin' | tee /etc/profile.d/cuda.sh > /dev/null
echo 'export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/cuda/lib64' | tee -a /etc/profile.d/cuda.sh > /dev/null
chmod 644 /etc/profile.d/cuda.sh

write_component_version "CUDA" ${CUDA_DRIVER_VERSION}

$COMPONENT_DIR/install_cuda_samples.sh
$COMPONENT_DIR/install_gdrcopy.sh
$COMPONENT_DIR/configure_nvidia_persistence.sh

# cleanup downloaded files
rm -rf *.run *.tar.gz *.rpm
rm -rf -- */
