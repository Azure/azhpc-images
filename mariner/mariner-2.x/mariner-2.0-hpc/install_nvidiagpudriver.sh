#!/bin/bash
set -ex

# Setup Mariner NVIDIA packages repo
curl https://packages.microsoft.com/cbl-mariner/2.0/prod/nvidia/x86_64/config.repo > /etc/yum.repos.d/mariner-nvidia-prod.repo

# Install signed NVIDIA driver
nvidia_driver_metadata=$(jq -r '.nvidia."'"$DISTRIBUTION"'".driver' <<< $COMPONENT_VERSIONS)
NVIDIA_DRIVER_VERSION=$(jq -r '.version' <<< $nvidia_driver_metadata)
tdnf install -y cuda-$NVIDIA_DRIVER_VERSION # Note: Nvidia driver is named cuda in Mariner packages repo
$COMMON_DIR/write_component_version.sh "nvidia" $NVIDIA_DRIVER_VERSION

# Set the CUDA driver versions
cuda_metadata=$(jq -r '.cuda."'"$DISTRIBUTION"'"' <<< $COMPONENT_VERSIONS)
CUDA_DRIVER_VERSION=$(jq -r '.driver.version' <<< $cuda_metadata)
CUDA_DRIVER_DISTRIBUTION=$(jq -r '.driver.distribution' <<< $cuda_metadata)
CUDA_SAMPLES_VERSION=$(jq -r '.samples.version' <<< $cuda_metadata)
CUDA_SAMPLES_SHA256=$(jq -r '.samples.sha256' <<< $cuda_metadata)

# Install Cuda
dnf config-manager --add-repo https://developer.download.nvidia.com/compute/cuda/repos/${CUDA_DRIVER_DISTRIBUTION}/x86_64/cuda-${CUDA_DRIVER_DISTRIBUTION}.repo
tdnf clean expire-cache
tdnf install cuda-toolkit-${CUDA_DRIVER_VERSION} -y
echo 'export PATH=$PATH:/usr/local/cuda/bin' | tee -a /etc/bash.bashrc
echo 'export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/cuda/lib64' | tee -a /etc/bash.bashrc
$COMMON_DIR/write_component_version.sh "CUDA" ${CUDA_DRIVER_VERSION}

# Download CUDA samples
TARBALL="v${CUDA_SAMPLES_VERSION}.tar.gz"
CUDA_SAMPLES_DOWNLOAD_URL=https://github.com/NVIDIA/cuda-samples/archive/refs/tags/${TARBALL}
$COMMON_DIR/download_and_verify.sh $CUDA_SAMPLES_DOWNLOAD_URL $CUDA_SAMPLES_SHA256
tar -xvf ${TARBALL}
pushd ./cuda-samples-${CUDA_SAMPLES_VERSION}
make -j $(nproc)
mv -vT ./Samples /usr/local/cuda-${CUDA_SAMPLES_VERSION}/samples
popd

# Temporarily install NV Peer Memory
./install_nv_peer_memory.sh

# Install GDRCopy
GDRCOPY_VERSION=$(jq -r '.gdrcopy."'"$DISTRIBUTION"'".version' <<< $COMPONENT_VERSIONS)
TARBALL="v${GDRCOPY_VERSION}.tar.gz"
GDRCOPY_DOWNLOAD_URL=https://github.com/NVIDIA/gdrcopy/archive/refs/tags/${TARBALL}
$COMMON_DIR/download_and_verify.sh $GDRCOPY_DOWNLOAD_URL "b85d15901889aa42de6c4a9233792af40dd94543e82abe0439e544c87fd79475" #TODO: put sha256 in requirements.txt
tar -xvf $TARBALL

pushd gdrcopy-${GDRCOPY_VERSION}/packages/
CUDA=/usr/local/cuda ./build-rpm-packages.sh
rpm -Uvh gdrcopy-kmod-${GDRCOPY_VERSION}-1dkms*.rpm
rpm -Uvh gdrcopy-${GDRCOPY_VERSION}-1.x86_64*.rpm
rpm -Uvh gdrcopy-devel-${GDRCOPY_VERSION}-1*.rpm
sed -i "$ s/$/ gdrcopy*/" /etc/dnf/dnf.conf
popd
$COMMON_DIR/write_component_version.sh "GDRCOPY" ${GDRCOPY_VERSION}

# Install nvidia fabric manager (required for ND96asr_v4)
./install_nvidia_fabric_manager.sh

# cleanup downloaded files
rm -rf *.run *tar.gz *.rpm
rm -rf -- */
