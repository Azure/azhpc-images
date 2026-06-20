#!/bin/bash
set -ex

source ${UTILS_DIR}/utilities.sh

# Install NVIDIA driver
nvidia_metadata=$(get_component_config "nvidia")
cuda_metadata=$(get_component_config "cuda")

function sanitize_nvidia_mig_mode {
    if ! command -v nvidia-smi >/dev/null 2>&1; then
        echo "nvidia-smi not found; skipping MIG sanitization"
        return 0
    fi

    local mig_query_output
    mig_query_output=$(nvidia-smi --query-gpu=index,mig.mode.current --format=csv,noheader,nounits 2>/dev/null || true)
    if [[ -z "${mig_query_output}" ]]; then
        echo "No NVIDIA GPUs detected; skipping MIG sanitization"
        return 0
    fi

    local mig_enabled_gpus
    mig_enabled_gpus=$(awk -F, '$2 ~ /Enabled/ { gsub(/^[ \t]+|[ \t]+$/, "", $1); print $1 }' <<< "${mig_query_output}" | paste -sd, -)
    if [[ -z "${mig_enabled_gpus}" ]]; then
        echo "No GPUs have MIG mode enabled"
        return 0
    fi

    echo "Disabling MIG mode on GPU(s): ${mig_enabled_gpus}"
    systemctl stop nvidia-fabricmanager.service nvidia-persistenced.service 2>/dev/null || true
    nvidia-smi -i "${mig_enabled_gpus}" -mig 0
    nvidia-smi --query-gpu=index,name,mig.mode.current,mig.mode.pending --format=csv,noheader
}

if [[ $DISTRIBUTION == "azurelinux3.0" ]]; then
    if [ "$SKU" = "V100" ]; then
        # V100 requires proprietary kernel modules
        AL3_GPU_DRIVER_PACKAGES="cuda"
    elif [ "$ARCHITECTURE" = "aarch64" ]; then
        AL3_GPU_DRIVER_PACKAGES="cuda-open-hwe"
    else
        AL3_GPU_DRIVER_PACKAGES="cuda-open"
    fi

    if [[ "$ARCHITECTURE" == "aarch64" ]]; then
        curl https://packages.microsoft.com/azurelinux/3.0/prod/nvidia/aarch64/config.repo > /etc/yum.repos.d/azurelinux-nvidia-prod.repo
        curl https://developer.download.nvidia.com/compute/cuda/repos/azl3/sbsa/cuda-azl3.repo > /etc/yum.repos.d/cuda-azl3.repo
    else
        curl https://packages.microsoft.com/azurelinux/3.0/prod/nvidia/x86_64/config.repo > /etc/yum.repos.d/azurelinux-nvidia-prod.repo
        curl https://developer.download.nvidia.com/compute/cuda/repos/azl3/x86_64/cuda-azl3.repo > /etc/yum.repos.d/cuda-azl3.repo
    fi

    # Disable the NVIDIA CUDA repo during driver install -- all driver
    # packages come from PMC and the CUDA repo has an identically-named
    # 'cuda' meta-package that would conflict.
    dnf install -y --disablerepo='cuda-azl3*' $AL3_GPU_DRIVER_PACKAGES
    NVIDIA_DRIVER_VERSION=$(dnf list installed | grep "^${AL3_GPU_DRIVER_PACKAGES}\." | sed 's/.*\s\+\([0-9.]\+-[0-9]\+\)_.*/\1/')

    # Keep later dnf operations from moving the PMC-installed driver family.
    dnf versionlock add "${AL3_GPU_DRIVER_PACKAGES}"
elif [[ $DISTRIBUTION == *"ubuntu"* ]]; then
    # APT-based NVIDIA driver installation for Ubuntu
    NVIDIA_DRIVER_VERSION=$(jq -r '.driver.version' <<< $nvidia_metadata)
    CUDA_DRIVER_DISTRIBUTION=$(jq -r '.driver.distribution' <<< $cuda_metadata)

    # Add NVIDIA CUDA APT repo (provides both driver and toolkit packages)
    wget https://developer.download.nvidia.com/compute/cuda/repos/${CUDA_DRIVER_DISTRIBUTION}/x86_64/cuda-keyring_1.1-1_all.deb
    dpkg -i ./cuda-keyring_1.1-1_all.deb
    apt-get update

    # Pin the driver version and install via APT packages
    apt install nvidia-driver-pinning-${NVIDIA_DRIVER_VERSION} -y
    if [ "$SKU" = "V100" ]; then
        # V100 requires proprietary kernel modules
        apt install cuda-drivers -y
    else
        # A100, H100, H200 use open kernel modules
        apt install nvidia-open -y
    fi

    # Remove unused configuration file if created by the NVIDIA driver package
    rm -f /etc/modprobe.d/nvidia-graphics-drivers-kms.conf

    # Apply nvprofiling settings
    echo 'options nvidia NVreg_RestrictProfilingToAdminUsers=0' | tee /etc/modprobe.d/nvprofiling.conf

    # nvidia-peermem is NOT modprobe'd at build time. Loading it before the
    # first reboot is fragile across the matrix of distros / kernels we
    # support (e.g. Ubuntu 26.04 needs DOCA-OFED's patched ib_core in
    # /lib/modules/$(uname -r)/updates/dkms/ which is not active in the
    # build kernel; general-purpose build SKUs have no IB hardware to load
    # against; baremetal builds reboot before IB is fully up). The module is
    # queued for first boot via /etc/modules-load.d/nvidia-peermem.conf
    # written below and via the openibd ExecStartPost drop-in installed by
    # setup_sku_customizations.sh.
else
    # RHEL-family: AlmaLinux, Rocky Linux, RHEL - .run file installation
    NVIDIA_DRIVER_VERSION=$(jq -r '.driver.version' <<< $nvidia_metadata)
    NVIDIA_DRIVER_SHA256=$(jq -r '.driver.sha256' <<< $nvidia_metadata)
    NVIDIA_DRIVER_URL=https://us.download.nvidia.com/tesla/${NVIDIA_DRIVER_VERSION}/NVIDIA-Linux-x86_64-${NVIDIA_DRIVER_VERSION}.run
    CUDA_DRIVER_DISTRIBUTION=$(jq -r '.driver.distribution' <<< $cuda_metadata)

    if [ "$SKU" = "V100" ]; then
        KERNEL_MODULE_TYPE="proprietary"
    else
        KERNEL_MODULE_TYPE="open"
    fi

    download_and_verify $NVIDIA_DRIVER_URL ${NVIDIA_DRIVER_SHA256}
    bash NVIDIA-Linux-x86_64-${NVIDIA_DRIVER_VERSION}.run --silent --dkms --kernel-module-type=${KERNEL_MODULE_TYPE}
    if [[ $DISTRIBUTION == almalinux* ]] || [[ $DISTRIBUTION == rocky* ]] || [[ $DISTRIBUTION == rhel* ]]; then
        dkms install --no-depmod -m nvidia -v ${NVIDIA_DRIVER_VERSION} -k `uname -r` --force
    fi
    # nvidia-peermem is NOT modprobe'd at build time -- see comment in the
    # Ubuntu branch above. The module is queued for first boot via
    # /etc/modules-load.d/nvidia-peermem.conf written below and via the
    # openibd ExecStartPost drop-in installed by setup_sku_customizations.sh.
fi
write_component_version "NVIDIA" ${NVIDIA_DRIVER_VERSION}
sanitize_nvidia_mig_mode

touch /etc/modules-load.d/nvidia-peermem.conf
echo "nvidia_peermem" >> /etc/modules-load.d/nvidia-peermem.conf

if [[ "$DISTRIBUTION" != *-aks ]]; then
    # Install CUDA toolkit
    CUDA_DRIVER_VERSION=$(jq -r '.driver.version' <<< $cuda_metadata)
    CUDA_SAMPLES_VERSION=$(jq -r '.samples.version' <<< $cuda_metadata)
    CUDA_SAMPLES_SHA256=$(jq -r '.samples.sha256' <<< $cuda_metadata)

    if [[ $DISTRIBUTION == *"ubuntu"* ]]; then
        # NVIDIA APT repo already configured during driver installation
        apt install -y cuda-toolkit-${CUDA_DRIVER_VERSION//./-}
    elif [[ $DISTRIBUTION == "azurelinux3.0" ]]; then    
        dnf install -y cuda-toolkit-${CUDA_DRIVER_VERSION//./-}
    else
        # RHEL-family: AlmaLinux, Rocky Linux, RHEL, etc.
        dnf config-manager --add-repo https://developer.download.nvidia.com/compute/cuda/repos/${CUDA_DRIVER_DISTRIBUTION}/x86_64/cuda-${CUDA_DRIVER_DISTRIBUTION}.repo

        # DOCA ships mft tied to the kernel-mft-dkms it built; cuda-rhel9
        # ships mft on a different cadence (sometimes newer). Letting
        # cuda-rhel9 offer mft causes 'dnf check-update' to flag a
        # stale-package upgrade in verify_package_updates and risks an
        # accidental upgrade that breaks compat with the DOCA-built
        # kernel-mft-dkms. mft must track DOCA, not CUDA. Same pattern as
        # install_nvidia_fabric_manager.sh excluding nvidia-fabricmanager*
        # from cuda-azl3 on AzureLinux 3, and a per-repo replacement for
        # the (removed) global DOCA pin in install_doca.sh.
        # There is also an obsoletion of CUDA 13 cccl against cuda-cccl in CUDA 12 we'd like to avoid.
        cuda_excludes="mft* kernel-mft*"
        if [[ "${CUDA_DRIVER_VERSION}" == 12.* ]]; then
            cuda_excludes="${cuda_excludes} cccl-*"
        fi

        dnf config-manager --save \
            --setopt="cuda-${CUDA_DRIVER_DISTRIBUTION}-x86_64.excludepkgs=${cuda_excludes}" >/dev/null

        dnf clean expire-cache
        dnf install -y cuda-toolkit-${CUDA_DRIVER_VERSION//./-}
    fi

    echo 'export PATH="${PATH:+$PATH:}/usr/local/cuda/bin"' | tee /etc/profile.d/cuda.sh > /dev/null
    echo 'export LD_LIBRARY_PATH="${LD_LIBRARY_PATH:+$LD_LIBRARY_PATH:}/usr/local/cuda/lib64"' | tee -a /etc/profile.d/cuda.sh > /dev/null

    # Ensure proper permissions
    chmod 644 /etc/profile.d/cuda.sh

    cuda_version=$(source /etc/profile; nvcc --version | grep release | awk '{print $6}' | cut -c2-)
    write_component_version "CUDA" ${cuda_version}

    $COMPONENT_DIR/install_cuda_samples.sh

fi

$COMPONENT_DIR/install_gdrcopy.sh

if [ "${SKU_FAMILY}" != "gb-family" ]; then
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
    dnf install -y nvidia-imex-${IMEX_VERSION}

    # Add configuration to /etc/modprobe.d/nvidia.conf
    cat <<EOF >> /etc/modprobe.d/nvidia.conf
options nvidia NVreg_CreateImexChannel0=1
EOF

    # Ensure modprobe settings are available when nvidia module loads on next boot
    dracut --force

    # Configuring nvidia-imex service
    systemctl enable nvidia-imex.service

fi

$COMPONENT_DIR/configure_nvidia_persistence.sh

# cleanup downloaded files
rm -rf *.run *.tar.gz *.rpm
(
    shopt -s dotglob nullglob
    rm -rf -- */ || true
)