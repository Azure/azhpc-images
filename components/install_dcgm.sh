#!/bin/bash
set -ex

source ${UTILS_DIR}/utilities.sh

# CUDA major version supported by the installed NVIDIA driver. Query the
# installed userspace driver library directly instead of calling nvidia-smi,
# which requires GPU hardware. cuDriverGetVersion returns the supported CUDA
# version as 1000 * major + 10 * minor (for example, 9020 for CUDA 9.2 and
# 13000 for CUDA 13.0); DCGM package names are keyed by the major version.
CUDA_DRIVER_SUPPORTED_VERSION=$(
    cuda_probe_dir=$(mktemp -d)
    trap 'rm -rf "${cuda_probe_dir}"' EXIT

    cat > "${cuda_probe_dir}/cuda_driver_api_version.c" <<'EOF'
#include <dlfcn.h>
#include <stdio.h>

typedef int (*cuDriverGetVersionFn)(int *);

int main(void) {
    int exit_code = 1;
    int cuda_driver_api_version = 0;
    void *cuda_library = NULL;

    cuda_library = dlopen("libcuda.so.1", RTLD_NOW);
    if (cuda_library == NULL) {
        fprintf(stderr, "Unable to load libcuda.so.1: %s\n", dlerror());
        goto cleanup;
    }

    cuDriverGetVersionFn cuDriverGetVersion = (cuDriverGetVersionFn)dlsym(cuda_library, "cuDriverGetVersion");
    if (cuDriverGetVersion == NULL) {
        fprintf(stderr, "Unable to find cuDriverGetVersion in libcuda.so.1: %s\n", dlerror());
        goto cleanup;
    }

    int result = cuDriverGetVersion(&cuda_driver_api_version);
    if (result != 0 || cuda_driver_api_version <= 0) {
        fprintf(stderr, "Unable to query CUDA driver API version from libcuda.so.1\n");
        goto cleanup;
    }

    printf("%d\n", cuda_driver_api_version);
    exit_code = 0;

cleanup:
    if (cuda_library != NULL) {
        dlclose(cuda_library);
    }

    return exit_code;
}
EOF

    gcc "${cuda_probe_dir}/cuda_driver_api_version.c" -ldl -o "${cuda_probe_dir}/cuda_driver_api_version"
    "${cuda_probe_dir}/cuda_driver_api_version"
)
CUDA_VERSION=$((CUDA_DRIVER_SUPPORTED_VERSION / 1000))

# Check for SKU-specific CUDA version in versions.json that may be lower
cuda_metadata=$(get_component_config "cuda")
SKU_CUDA_VERSION=$(jq -r '.driver.version' <<< $cuda_metadata | cut -d'.' -f1)

# Install DCGM
# Reference: https://developer.nvidia.com/dcgm#Downloads
# the repo is already added during nvidia/ cuda installations

if [[ $DISTRIBUTION == *"ubuntu"* ]]; then
    # Get DCGM version from versions.json
    dcgm_metadata=$(get_component_config "dcgm")
    DCGM_VERSION=$(jq -r '.version' <<< $dcgm_metadata)
    apt-get install -y \
        datacenter-gpu-manager-4-cuda${CUDA_VERSION}=${DCGM_VERSION} \
        datacenter-gpu-manager-4-core=${DCGM_VERSION} \
        datacenter-gpu-manager-4-proprietary=${DCGM_VERSION} \
        datacenter-gpu-manager-4-proprietary-cuda${CUDA_VERSION}=${DCGM_VERSION}

    # Nvidia documentation says that "Generally speaking, users should install binaries targeting the major version of the CUDA user-mode driver that's installed on their system."
    # but that v100 "is not supported by version 13.0.0 of the CUDA Toolkit. Consequently, Maxwell, Volta, and Pascal systems using driver version 580 should install DCGM packages targeting major version 12
    # of the user-mode driver (e.g. datacenter-gpu-manager-4-cuda12) rather than DCGM packages targeting major version 13."
    # In practice though, DCGM requires both cuda12 and cuda13 support packages (https://github.com/NVIDIA/DCGM/issues/254).
    if [[ "${SKU_CUDA_VERSION}" -lt "${CUDA_VERSION}" ]]; then
        echo "Installing DCGM packages for SKU-specific CUDA ${SKU_CUDA_VERSION}"
        apt-get install -y \
            datacenter-gpu-manager-4-cuda${SKU_CUDA_VERSION}=${DCGM_VERSION} \
            datacenter-gpu-manager-4-proprietary-cuda${SKU_CUDA_VERSION}=${DCGM_VERSION}
    fi
elif [[ $DISTRIBUTION == *"azurelinux"* ]]; then
    # Get DCGM version from versions.json
    dcgm_metadata=$(get_component_config "dcgm")
    DCGM_VERSION=$(jq -r '.version' <<< $dcgm_metadata)
    # V100 does not support CUDA 13.0
    # so use DCGM compatible with CUDA 12
    if [ "$1" = "V100" ]; then
        tdnf install -y datacenter-gpu-manager-4-cuda12-${DCGM_VERSION}
    else
        tdnf install -y datacenter-gpu-manager-4-cuda13-${DCGM_VERSION}
    fi
else
    # RHEL-family: AlmaLinux, Rocky Linux, RHEL, etc.
    dnf clean expire-cache
    dnf install --assumeyes --setopt=install_weak_deps=True datacenter-gpu-manager-4-cuda${CUDA_VERSION}
    # V100 needs cuda12 DCGM packages in addition to cuda13 (same as Ubuntu logic above)
    if [[ "${SKU_CUDA_VERSION}" -lt "${CUDA_VERSION}" ]]; then
        echo "Installing DCGM packages for SKU-specific CUDA ${SKU_CUDA_VERSION}"
        dnf install --assumeyes --setopt=install_weak_deps=True datacenter-gpu-manager-4-cuda${SKU_CUDA_VERSION}
    fi
    DCGM_VERSION=$(dcgmi --version | awk '{print $3}')
fi

write_component_version "DCGM" ${DCGM_VERSION}

# Enable the dcgm service
systemctl --now enable nvidia-dcgm
systemctl start nvidia-dcgm
# Check if the service is active
systemctl is-active --quiet nvidia-dcgm
error_code=$?
if [ ${error_code} -ne 0 ]
then
    echo "DCGM is inactive!"
    exit ${error_code}
fi
