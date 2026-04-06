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

        # Patch the vm_flags_set conftest to add a grep-based fallback.
        # The compile-based test can fail due to compiler mismatch (e.g. cross-compiler
        # vs native on aarch64) or struct changes in newer kernels (>= 6.3), even when
        # vm_flags_set is defined in linux/mm.h. This causes HAVE_VM_FLAGS_SET=n and a
        # redefinition error when building gdrdrv against kernel 6.14+.
        CONFTEST_SCRIPT="../scripts/test_gdrdrv_HAVE_VM_FLAGS_SET.sh"
        if [ -f "${CONFTEST_SCRIPT}" ]; then
            sed -i '/^if \[ "\${ret}" -eq 0 \]; then$/i \
        # Fallback: if compile test failed, check kernel headers directly for vm_flags_set\
        if [ "${ret}" -ne 0 ]; then\
            if grep -q "\\bvm_flags_set\\b" "${kdir}/include/linux/mm.h" 2>/dev/null; then\
                ret=0\
            fi\
        fi' "${CONFTEST_SCRIPT}"
        fi

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
write_component_version "GDRCOPY" ${GDRCOPY_VERSION}
