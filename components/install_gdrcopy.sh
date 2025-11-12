#!/bin/bash
set -ex

source ${UTILS_DIR}/utilities.sh

gdrcopy_metadata=$(get_component_config "gdrcopy")
GDRCOPY_VERSION=$(jq -r '.version' <<< $gdrcopy_metadata)
GDRCOPY_COMMIT=$(jq -r '.commit' <<< $gdrcopy_metadata)
GDRCOPY_DISTRIBUTION=$(jq -r '.distribution' <<< $gdrcopy_metadata)

if [[ $DISTRIBUTION == "azurelinux3.0" ]]; then
    kernel_version=$(uname -r | sed 's/\-/./g')
    kernel_version=${kernel_version%.*}

    nvidia_driver_metadata=$(get_component_config "nvidia")
    NVIDIA_DRIVER_VERSION=$(jq -r '.driver.version' <<< $nvidia_driver_metadata)
    NVIDIA_DRIVER_VERSION=$(echo $NVIDIA_DRIVER_VERSION | cut -d'-' -f1 )
    
    # Install gdrcopy kmod and devel packages from PMC
    tdnf install -y gdrcopy-${GDRCOPY_VERSION}.azl3.x86_64 \
                    gdrcopy-kmod-${GDRCOPY_VERSION}_$kernel_version.$NVIDIA_DRIVER_VERSION.azl3.x86_64 \
                    gdrcopy-devel-${GDRCOPY_VERSION}.azl3.noarch
else
    git clone https://github.com/NVIDIA/gdrcopy.git
    pushd gdrcopy/packages/
    git checkout ${GDRCOPY_COMMIT}
    if [[ $DISTRIBUTION == *"ubuntu"* ]]; then
        # Install gdrcopy
        apt install -y build-essential devscripts debhelper check libsubunit-dev fakeroot pkg-config dkms

        cuda_metadata=$(get_component_config "cuda")
        CUDA_DRIVER_VERSION=$(jq -r '.driver.version' <<< $cuda_metadata)

        CUDA=/usr/local/cuda ./build-deb-packages.sh 
        dpkg -i gdrdrv-dkms_${GDRCOPY_VERSION}_amd64.${GDRCOPY_DISTRIBUTION}.deb
        apt-mark hold gdrdrv-dkms
        dpkg -i libgdrapi_${GDRCOPY_VERSION}_amd64.${GDRCOPY_DISTRIBUTION}.deb
        apt-mark hold libgdrapi
        dpkg -i gdrcopy-tests_${GDRCOPY_VERSION}_amd64.${GDRCOPY_DISTRIBUTION}+cuda${CUDA_DRIVER_VERSION}.deb
        apt-mark hold gdrcopy-tests
        dpkg -i gdrcopy_${GDRCOPY_VERSION}_amd64.${GDRCOPY_DISTRIBUTION}.deb
        apt-mark hold gdrcopy
    elif [[ $DISTRIBUTION == almalinux* ]]; then
        nvidia_metadata=$(get_component_config "nvidia")
        nvidia_driver_metadata=$(jq -r '.driver' <<< $nvidia_metadata)
        NVIDIA_DRIVER_VERSION=$(jq -r '.version' <<< $nvidia_driver_metadata)

        CUDA=/usr/local/cuda ./build-rpm-packages.sh -m
        rpm -Uvh gdrcopy-kmod-${GDRCOPY_VERSION}dkms.${GDRCOPY_DISTRIBUTION}.noarch.rpm
        rpm -Uvh gdrcopy-${GDRCOPY_VERSION}.${GDRCOPY_DISTRIBUTION}.x86_64.rpm
        rpm -Uvh gdrcopy-devel-${GDRCOPY_VERSION}.${GDRCOPY_DISTRIBUTION}.noarch.rpm
        rpm -Uvh gdrcopy-kmod-$(uname -r)-nvidia-${NVIDIA_DRIVER_VERSION}-${GDRCOPY_VERSION}.${GDRCOPY_DISTRIBUTION}.x86_64.rpm
        sed -i "$ s/$/ gdrcopy*/" /etc/dnf/dnf.conf
    fi
    popd
fi
write_component_version "GDRCOPY" ${GDRCOPY_VERSION}
