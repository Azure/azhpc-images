#!/bin/bash
set -ex

source ${UTILS_DIR}/utilities.sh

gdrcopy_metadata=$(get_component_config "gdrcopy")
GDRCOPY_VERSION=$(jq -r '.version' <<< $gdrcopy_metadata)
GDRCOPY_COMMIT=$(jq -r '.commit' <<< $gdrcopy_metadata)
GDRCOPY_DISTRIBUTION=$(jq -r '.distribution' <<< $gdrcopy_metadata)

if [[ "$DISTRIBUTION" == *-aks ]]; then 
    if [[ "$DISTRIBUTION" == ubuntu2*-aks ]]; then
        # Install gdrcopy
        apt install -y build-essential devscripts debhelper check libsubunit-dev fakeroot pkg-config dkms

        cuda_metadata=$(get_component_config "cuda")
        CUDA_DRIVER_VERSION=$(jq -r '.driver.version' <<< $cuda_metadata)


        wget https://developer.download.nvidia.com/compute/redist/gdrcopy/CUDA%20${CUDA_DRIVER_VERSION}/${GDRCOPY_DISTRIBUTION,}/${ARCHITECTURE}/gdrdrv-dkms_${GDRCOPY_VERSION}_arm64.${GDRCOPY_DISTRIBUTION}.deb
        dpkg -i gdrdrv-dkms_${GDRCOPY_VERSION}_arm64.${GDRCOPY_DISTRIBUTION}.deb

        write_component_version "GDRCOPY" ${GDRCOPY_VERSION}
    fi
else    
    if [[ $DISTRIBUTION == "azurelinux3.0" ]]; then
        kernel_version=$(uname -r | sed 's/\-/./g')
        kernel_version=${kernel_version%.*}

        # tdnf will automatically pick the correct nvidia driver version for
        # gdrcopy kmod package

        if [ "$ARCHITECTURE" = "aarch64" ]; then
            # Install gdrcopy kmod and devel packages from PMC
            tdnf -y install gdrcopy \
                            gdrcopy-hwe-kmod \
                            gdrcopy-devel \
                            gdrcopy-service
            GDRCOPY_VERSION=$(sudo tdnf list installed | grep -i gdrcopy.aarch64 | sed 's/.*[[:space:]]\([0-9.]*-[0-9]*\)\..*/\1/')
        else
            # Install gdrcopy kmod and devel packages from PMC
            tdnf install -y gdrcopy \
                            gdrcopy-kmod \
                            gdrcopy-devel \
                            gdrcopy-service
            GDRCOPY_VERSION=$(sudo tdnf list installed | grep -i gdrcopy.x86_64 | sed 's/.*[[:space:]]\([0-9.]*-[0-9]*\)\..*/\1/')
        fi

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
            dpkg -i gdrdrv-dkms_${GDRCOPY_VERSION}_${ARCHITECTURE_DISTRO}.${GDRCOPY_DISTRIBUTION}.deb
            apt-mark hold gdrdrv-dkms
            dpkg -i libgdrapi_${GDRCOPY_VERSION}_${ARCHITECTURE_DISTRO}.${GDRCOPY_DISTRIBUTION}.deb
            apt-mark hold libgdrapi
            dpkg -i gdrcopy-tests_${GDRCOPY_VERSION}_${ARCHITECTURE_DISTRO}.${GDRCOPY_DISTRIBUTION}+cuda${CUDA_DRIVER_VERSION}.deb
            apt-mark hold gdrcopy-tests
            dpkg -i gdrcopy_${GDRCOPY_VERSION}_${ARCHITECTURE_DISTRO}.${GDRCOPY_DISTRIBUTION}.deb
            apt-mark hold gdrcopy
        elif [[ $DISTRIBUTION == almalinux* ]] || [[ $DISTRIBUTION == rocky* ]] || [[ $DISTRIBUTION == rhel* ]]; then
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
fi    
# Record the version the package manager actually registered, not the raw
# string from versions.json. For gdrcopy on Ubuntu, the .deb's control-file
# Version field is the upstream-only string (e.g. "2.5.2") even though the
# .deb filename and versions.json carry an explicit "-<rev>" suffix
# ("2.5.2-1"). components/refresh_component_versions.sh reads back via
# dpkg-query, so writing the same dpkg ${Version} here makes the manifest
# round-trip exactly across in-place refreshes.
GDRCOPY_INSTALLED_VERSION=""
if command -v dpkg-query &>/dev/null; then
    GDRCOPY_INSTALLED_VERSION=$(dpkg-query -W -f='${Version}' gdrcopy 2>/dev/null || true)
fi
if [[ -z "${GDRCOPY_INSTALLED_VERSION}" ]] && command -v rpm &>/dev/null; then
    GDRCOPY_INSTALLED_VERSION=$(rpm -q --qf '%{VERSION}-%{RELEASE}' gdrcopy 2>/dev/null || true)
    [[ "${GDRCOPY_INSTALLED_VERSION}" == *"not installed"* ]] && GDRCOPY_INSTALLED_VERSION=""
fi
write_component_version "GDRCOPY" "${GDRCOPY_INSTALLED_VERSION:-${GDRCOPY_VERSION}}"
