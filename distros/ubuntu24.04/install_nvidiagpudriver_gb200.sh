set -ex

source ${UTILS_DIR}/utilities.sh

cuda_metadata=$(get_component_config "cuda")
CUDA_DRIVER_VERSION=$(jq -r '.driver.version' <<< $cuda_metadata)
CUDA_DRIVER_DISTRIBUTION=$(jq -r '.driver.distribution' <<< $cuda_metadata)
CUDA_SAMPLES_VERSION=$(jq -r '.samples.version' <<< $cuda_metadata)
CUDA_SAMPLES_SHA256=$(jq -r '.samples.sha256' <<< $cuda_metadata)

wget https://developer.download.nvidia.com/compute/cuda/repos/${CUDA_DRIVER_DISTRIBUTION}/sbsa/cuda-keyring_1.1-1_all.deb
dpkg -i ./cuda-keyring_1.1-1_all.deb

apt-get update

if [[ $DISTRIBUTION != ubuntu24.04-aks ]]; then
    apt install -y cuda-toolkit-${CUDA_DRIVER_VERSION//./-}
    # Set CUDA related environment variables to /etc/bash.bashrc
    echo 'export CUDA_HOME=/usr/local/cuda' | tee -a /etc/profile
    echo 'export PATH=$CUDA_HOME/bin:$PATH' | tee -a /etc/profile
    echo 'export LD_LIBRARY_PATH=$CUDA_HOME/lib64:$LD_LIBRARY_PATH' | tee -a /etc/profile
    cuda_version=$(source /etc/profile; nvcc --version | grep release | awk '{print $6}' | cut -c2-)
    write_component_version "CUDA" ${cuda_version}

    # Download CUDA samples
    TARBALL="v${CUDA_SAMPLES_VERSION}.tar.gz"
    CUDA_SAMPLES_DOWNLOAD_URL=https://github.com/NVIDIA/cuda-samples/archive/refs/tags/${TARBALL}
    download_and_verify ${CUDA_SAMPLES_DOWNLOAD_URL} ${CUDA_SAMPLES_SHA256}
    tar -xvf ${TARBALL}
    pushd ./cuda-samples-${CUDA_SAMPLES_VERSION}
    mkdir build && cd build
    cmake -DCMAKE_CUDA_COMPILER=/usr/local/cuda/bin/nvcc ..
    make -j $(nproc)
    mv -vT ./Samples /usr/local/cuda-${CUDA_DRIVER_VERSION}/samples # Use the same version as the CUDA toolkit as thats where samples is being moved to
    popd
fi


# Install NVIDIA GPU driver
nvidia_gpu_driver_metadata=$(get_component_config "nvidia")
NVIDIA_GPU_DRIVER_MAJOR_VERSION=$(jq -r '.driver.major_version' <<< $nvidia_gpu_driver_metadata)
NVIDIA_GPU_DRIVER_VERSION=$(jq -r '.driver.version' <<< $nvidia_gpu_driver_metadata)
apt install nvidia-driver-pinning-$NVIDIA_GPU_DRIVER_VERSION -y

# Install the NVIDIA driver and related packages
apt install nvidia-dkms-$NVIDIA_GPU_DRIVER_MAJOR_VERSION-open nvidia-driver-$NVIDIA_GPU_DRIVER_MAJOR_VERSION-open nvidia-modprobe -y

# remove unused configuration file if the file was created by the NVIDIA driver
rm /etc/modprobe.d/nvidia-graphics-drivers-kms.conf

# Apply nvprofiling settings
echo 'options nvidia NVreg_RestrictProfilingToAdminUsers=0' | tee /etc/modprobe.d/nvprofiling.conf

# Persist CDMM (Coherent GPU Memory Mode) = "driver" for first boot.
# Doing the live `modprobe nvidia NVreg_CoherentGPUMemoryMode=driver` here was
# previously used to flip the running build kernel into CDMM mode, but it
# requires a coherent ARM/Blackwell GPU to be present (i.e. an actual GB200
# build SKU). The /etc/modprobe.d entry alone is sufficient: the very next
# `modprobe nvidia` -- which happens on the customer VM's first boot via the
# /etc/modules-load.d/nvidia-peermem.conf chain, udev, or systemd auto-load --
# picks up the option from modprobe.d.
echo options nvidia NVreg_CoherentGPUMemoryMode=driver > /etc/modprobe.d/nvidia-openrm.conf

$COMPONENT_DIR/configure_nvidia_persistence.sh

# Write the installed driver version from dpkg metadata (do NOT call
# nvidia-smi here: it requires a real NVIDIA GPU and fails on
# general-purpose build SKUs). dpkg returns the Debian package version (for
# example, 580.105.08-0ubuntu1); nvidia-smi reports the upstream driver
# version, so strip any Debian revision/epoch before writing component data.
nvidia_driver_package_version=$(dpkg-query -W -f='${Version}' "nvidia-driver-${NVIDIA_GPU_DRIVER_MAJOR_VERSION}-open")
nvidia_driver_version=${nvidia_driver_package_version%%-*}
nvidia_driver_version=${nvidia_driver_version##*:}
write_component_version "NVIDIA" "${nvidia_driver_version}"


$COMPONENT_DIR/install_gdrcopy.sh

# Install NVIDIA IMEX
apt-get install nvidia-imex -y

# Add configuration to /etc/modprobe.d/nvidia.conf
cat <<EOF >> /etc/modprobe.d/nvidia.conf
options nvidia NVreg_CreateImexChannel0=1
EOF

sudo update-initramfs -u -k all

# Configuring nvidia-imex service
systemctl enable nvidia-imex.service

nvidia_imex_version=$(nvidia-imex --version | grep -oP 'IMEX version is: \K[0-9.]+')
write_component_version "IMEX" $nvidia_imex_version