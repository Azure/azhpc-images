#!/bin/bash
set -ex

aks_host_image=$1

source ${UTILS_DIR}/utilities.sh

# Install NVIDIA driver
nvidia_metadata=$(get_component_config "nvidia")
nvidia_driver_metadata=$(jq -r '.driver' <<< $nvidia_metadata)
NVIDIA_DRIVER_VERSION=$(jq -r '.version' <<< $nvidia_driver_metadata)
NVIDIA_DRIVER_SHA256=$(jq -r '.sha256' <<< $nvidia_driver_metadata)
NVIDIA_DRIVER_URL=https://us.download.nvidia.com/tesla/${NVIDIA_DRIVER_VERSION}/NVIDIA-Linux-x86_64-${NVIDIA_DRIVER_VERSION}.run
kernel_version=$(uname -r | sed 's/\-/./g')

if [ "$SKU" = "V100" ]; then
    KERNEL_MODULE_TYPE="proprietary"
    # Install Nvidia GPU propreitary variant for V100 and older SKUs
    AL3_GPU_DRIVER_PACKAGES="cuda-${NVIDIA_DRIVER_VERSION}"
else
    KERNEL_MODULE_TYPE="open"
    # Install Nvidia GPU open source variant for A100, H100
    if [ "$ARCHITECTURE" = "aarch64" ]; then
        # Install Nvidia GPU open source variant for GB200 GB300
        AL3_GPU_DRIVER_PACKAGES="cuda-open-hwe"
    else
        # Install Nvidia GPU open source variant for A100, H100 
        AL3_GPU_DRIVER_PACKAGES="cuda-open"
    fi
fi

if [[ $DISTRIBUTION == "azurelinux3.0" ]]; then
    if [[ "$ARCHITECTURE" == "aarch64" ]]; then
        curl https://packages.microsoft.com/azurelinux/3.0/prod/nvidia/aarch64/config.repo > /etc/yum.repos.d/azurelinux-nvidia-prod.repo
        curl https://developer.download.nvidia.com/compute/cuda/repos/azl3/sbsa/cuda-azl3.repo > /etc/yum.repos.d/cuda-azl3.repo
    else
        curl https://packages.microsoft.com/azurelinux/3.0/prod/nvidia/x86_64/config.repo > /etc/yum.repos.d/azurelinux-nvidia-prod.repo
        curl https://developer.download.nvidia.com/compute/cuda/repos/azl3/x86_64/cuda-azl3.repo > /etc/yum.repos.d/cuda-azl3.repo
    fi

    tdnf install -y $AL3_GPU_DRIVER_PACKAGES
    NVIDIA_DRIVER_VERSION=$(sudo tdnf list installed | grep -i $AL3_GPU_DRIVER_PACKAGES | sed 's/.*\s\+\([0-9.]\+-[0-9]\+\)_.*/\1/')

    # Temp disable NVIDIA driver updates
    mkdir -p /etc/tdnf/locks.d
    echo cuda >> /etc/tdnf/locks.d/nvidia.conf
else
    download_and_verify $NVIDIA_DRIVER_URL ${NVIDIA_DRIVER_SHA256}
    bash NVIDIA-Linux-x86_64-${NVIDIA_DRIVER_VERSION}.run --silent --dkms --kernel-module-type=${KERNEL_MODULE_TYPE}
    if [[ $DISTRIBUTION == almalinux* ]]; then
        dkms install --no-depmod -m nvidia -v ${NVIDIA_DRIVER_VERSION} -k `uname -r` --force
    fi
    # load the nvidia-peermem coming as a part of NVIDIA GPU driver
    # Reference - https://download.nvidia.com/XFree86/Linux-x86_64/510.85.02/README/nvidia-peermem.html
    modprobe nvidia-peermem
    # verify if loaded
    lsmod | grep nvidia_peermem
fi
write_component_version "NVIDIA" ${NVIDIA_DRIVER_VERSION}

touch /etc/modules-load.d/nvidia-peermem.conf
echo "nvidia_peermem" >> /etc/modules-load.d/nvidia-peermem.conf

# Set the driver versions
cuda_metadata=$(get_component_config "cuda")
CUDA_DRIVER_VERSION=$(jq -r '.driver.version' <<< $cuda_metadata)
CUDA_DRIVER_DISTRIBUTION=$(jq -r '.driver.distribution' <<< $cuda_metadata)
CUDA_SAMPLES_VERSION=$(jq -r '.samples.version' <<< $cuda_metadata)
CUDA_SAMPLES_SHA256=$(jq -r '.samples.sha256' <<< $cuda_metadata)

if [[ "$DISTRIBUTION" != *-aks ]]; then
    # Install Cuda
    if [[ $DISTRIBUTION == *"ubuntu"* ]]; then
        # Dependency for nvidia driver installation
        apt-get install -y libvulkan1
        # Reference - https://docs.nvidia.com/cuda/cuda-installation-guide-linux/index.html#ubuntu-installation
        wget https://developer.download.nvidia.com/compute/cuda/repos/${CUDA_DRIVER_DISTRIBUTION}/x86_64/cuda-keyring_1.1-1_all.deb
        dpkg -i ./cuda-keyring_1.1-1_all.deb
        apt-get update
        apt install -y cuda-toolkit-${CUDA_DRIVER_VERSION//./-}
    elif [[ $DISTRIBUTION == almalinux* ]]; then
        dnf config-manager --add-repo https://developer.download.nvidia.com/compute/cuda/repos/${CUDA_DRIVER_DISTRIBUTION}/x86_64/cuda-${CUDA_DRIVER_DISTRIBUTION}.repo
        dnf clean expire-cache
        dnf install -y cuda-toolkit-${CUDA_DRIVER_VERSION//./-}
    elif [[ $DISTRIBUTION == "azurelinux3.0" ]]; then    
        # Install cuda-toolkit
        # V100 does not support CUDA 13.0, so use CUDA 12.9.
        if [ "$SKU" = "V100" ]; then
            tdnf install -y cuda-toolkit-12-9-12.9.1
        else
            tdnf install -y cuda-toolkit-13-0-13.0.2
        fi        
        # Install libnvidia-nscq
        tdnf install -y libnvidia-nscq
    fi

    echo 'export PATH=$PATH:/usr/local/cuda/bin' | sudo tee /etc/profile.d/cuda.sh > /dev/null
    echo 'export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/cuda/lib64' | sudo tee -a /etc/profile.d/cuda.sh > /dev/null

    # Ensure proper permissions
    sudo chmod 644 /etc/profile.d/cuda.sh

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

$COMPONENT_DIR/install_gdrcopy.sh

if [[ "$ARCHITECTURE" != "aarch64" ]]; then
    # Install nvidia fabric manager (required for ND96asr_v4)
    $COMPONENT_DIR/install_nvidia_fabric_manager.sh
else
    # Apply nvprofiling settings
    echo 'options nvidia NVreg_RestrictProfilingToAdminUsers=0' | tee /etc/modprobe.d/nvprofiling.conf

    # Enable CDMM mode
    echo 'options nvidia NVreg_CoherentGPUMemoryMode=driver' | tee /etc/modprobe.d/nvidia-openrm.conf
    
    # Install NVIDIA IMEX
    nvidia_imex_metadata=$(jq -r '.imex' <<< $nvidia_metadata)
    IMEX_VERSION=$(jq -r '.version' <<< $nvidia_imex_metadata)
    tdnf install -y nvidia-imex-${IMEX_VERSION}

    # Add configuration to /etc/modprobe.d/nvidia.conf
    cat <<EOF >> /etc/modprobe.d/nvidia.conf
options nvidia NVreg_CreateImexChannel0=1
EOF

    grep -q 'RMBug5172204War=4' /etc/modprobe.d/nvidia.conf 2>/dev/null || \
        echo 'options nvidia NVreg_RegistryDwords="RMBug5172204War=4"' | tee -a /etc/modprobe.d/nvidia.conf

    # Ensure modprobe settings are available when nvidia module loads on next boot
    dracut --force

    # Configuring nvidia-imex service
    systemctl enable nvidia-imex.service

fi

$COMPONENT_DIR/configure_nvidia_persistence.sh

# cleanup downloaded files
rm -rf *.run *tar.gz *.rpm
rm -rf -- */