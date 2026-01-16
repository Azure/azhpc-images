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
    write_component_version "CUDA" ${CUDA_DRIVER_VERSION}

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
NVIDIA_IMEX_VERSION=$(jq -r '.imex.version' <<< $nvidia_gpu_driver_metadata)
NVIDIA_PKG_VERSION="${NVIDIA_GPU_DRIVER_VERSION}-0ubuntu1"

# Pin the nvidia packages to the specified version to avoid unintended upgrades
sudo tee /etc/apt/preferences.d/00-nvidia-580-pin <<EOF
Package: nvidia-*
Pin: version ${NVIDIA_PKG_VERSION}
Pin-Priority: 1001

Package: libnvidia-*
Pin: version ${NVIDIA_PKG_VERSION}
Pin-Priority: 1001

Package: xserver-xorg-video-nvidia-*
Pin: version ${NVIDIA_PKG_VERSION}
Pin-Priority: 1001

Package: nvidia-imex
Pin: version ${NVIDIA_IMEX_VERSION}
Pin-Priority: 1001
EOF

# Install the NVIDIA driver and related packages
sudo apt-get install -y --allow-downgrades \
  nvidia-driver-${NVIDIA_GPU_DRIVER_MAJOR_VERSION}-open=${NVIDIA_PKG_VERSION} \
  nvidia-dkms-${NVIDIA_GPU_DRIVER_MAJOR_VERSION}-open=${NVIDIA_PKG_VERSION} \
  nvidia-kernel-common-${NVIDIA_GPU_DRIVER_MAJOR_VERSION}=${NVIDIA_PKG_VERSION} \
  nvidia-kernel-source-${NVIDIA_GPU_DRIVER_MAJOR_VERSION}-open=${NVIDIA_PKG_VERSION} \
  nvidia-firmware-${NVIDIA_GPU_DRIVER_MAJOR_VERSION}=${NVIDIA_PKG_VERSION} \
  libnvidia-common-${NVIDIA_GPU_DRIVER_MAJOR_VERSION}=${NVIDIA_PKG_VERSION} \
  libnvidia-cfg1-${NVIDIA_GPU_DRIVER_MAJOR_VERSION}=${NVIDIA_PKG_VERSION} \
  libnvidia-gpucomp-${NVIDIA_GPU_DRIVER_MAJOR_VERSION}=${NVIDIA_PKG_VERSION} \
  libnvidia-gl-${NVIDIA_GPU_DRIVER_MAJOR_VERSION}=${NVIDIA_PKG_VERSION} \
  libnvidia-compute-${NVIDIA_GPU_DRIVER_MAJOR_VERSION}=${NVIDIA_PKG_VERSION} \
  libnvidia-extra-${NVIDIA_GPU_DRIVER_MAJOR_VERSION}=${NVIDIA_PKG_VERSION} \
  libnvidia-decode-${NVIDIA_GPU_DRIVER_MAJOR_VERSION}=${NVIDIA_PKG_VERSION} \
  libnvidia-encode-${NVIDIA_GPU_DRIVER_MAJOR_VERSION}=${NVIDIA_PKG_VERSION} \
  libnvidia-fbc1-${NVIDIA_GPU_DRIVER_MAJOR_VERSION}=${NVIDIA_PKG_VERSION} \
  xserver-xorg-video-nvidia-${NVIDIA_GPU_DRIVER_MAJOR_VERSION}=${NVIDIA_PKG_VERSION} \
  nvidia-modprobe

# remove unused configuration file if the file was created by the NVIDIA driver
rm /etc/modprobe.d/nvidia-graphics-drivers-kms.conf

# Apply nvprofiling settings
echo 'options nvidia NVreg_RestrictProfilingToAdminUsers=0' | tee /etc/modprobe.d/nvprofiling.conf

# Enable CDMM mode
modprobe nvidia NVreg_CoherentGPUMemoryMode=driver 
echo options nvidia NVreg_CoherentGPUMemoryMode=driver > /etc/modprobe.d/nvidia-openrm.conf

# Configuring nvidia persistenced daemon
if [ ! -f /etc/systemd/system/nvidia-persistenced.service ]; then
    cat <<EOF > /etc/systemd/system/nvidia-persistenced.service
[Unit]
Description=NVIDIA Persistence Daemon
Wants=syslog.target
 
[Service]
Type=forking
PIDFile=/var/run/nvidia-persistenced/nvidia-persistenced.pid
Restart=always
ExecStart=/usr/bin/nvidia-persistenced --verbose --persistence-mode
ExecStopPost=/bin/rm -rf /var/run/nvidia-persistenced
 
[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable nvidia-persistenced.service
fi

systemctl restart nvidia-persistenced.service
systemctl status nvidia-persistenced.service
if ! systemctl is-active --quiet nvidia-persistenced.service; then
    echo "nvidia-persistenced service is not running. Exiting."
    exit 1
fi

# Verify the installation
nvidia-smi

# Write the driver versions to the component versions file
nvidia_driver_version=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader | head -n 1)
write_component_version "NVIDIA" $nvidia_driver_version


$COMPONENT_DIR/install_gdrcopy.sh

# Install NVIDIA IMEX
apt-get install nvidia-imex=${NVIDIA_IMEX_VERSION} -y --allow-downgrades

# Add configuration to /etc/modprobe.d/nvidia.conf
cat <<EOF >> /etc/modprobe.d/nvidia.conf
options nvidia NVreg_CreateImexChannel0=1
EOF

sudo update-initramfs -u -k all

# Configuring nvidia-imex service
systemctl enable nvidia-imex.service

nvidia_imex_version=$(nvidia-imex --version | grep -oP 'IMEX version is: \K[0-9.]+')
write_component_version "IMEX" $nvidia_imex_version