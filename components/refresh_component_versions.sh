#!/bin/bash
set -euo pipefail

# =============================================================================
# Refresh Component Versions
# =============================================================================
# Regenerates /opt/azurehpc/component_versions.txt by detecting the actual
# installed versions of all HPC components on the running system.
#
# This script is used during "in-place refresh" builds where an existing HPC
# image is used as a base and components are upgraded. Since the install scripts
# may not all be re-run, this script queries the system (package managers,
# binaries, modulefiles, etc.) to build an accurate manifest.
#
# Usage:
#   sudo bash refresh_component_versions.sh [GPU_PLATFORM]
#   GPU_PLATFORM: NVIDIA or AMD (default: NVIDIA)
#
# Output:
#   /opt/azurehpc/component_versions.txt (JSON)
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/utilities.sh" || { echo "ERROR: Failed to source utilities.sh from ${SCRIPT_DIR}/../utils/"; exit 1; }

GPU_PLATFORM="${1:-NVIDIA}"
COMPONENT_VERSIONS_FILE="/opt/azurehpc/component_versions.txt"

mkdir -p /opt/azurehpc

# Start with an empty JSON object (or preserve ImageVersion from existing file)
if [ -f "${COMPONENT_VERSIONS_FILE}" ]; then
    EXISTING_IMAGE_VERSION=$(jq -r '.ImageVersion // empty' "${COMPONENT_VERSIONS_FILE}" 2>/dev/null || true)
fi

echo '{}' > "${COMPONENT_VERSIONS_FILE}"

# Helper: write version only if non-empty
write_version() {
    local component="$1"
    local version="$2"
    if [[ -n "${version}" && "${version}" != "null" ]]; then
        write_component_version "${component}" "${version}"
        echo "  [OK] ${component} = ${version}"
    else
        echo "  [--] ${component} not detected"
    fi
}

echo "=== Refreshing component_versions.txt ==="
echo "GPU Platform: ${GPU_PLATFORM}"
echo ""

# ---- OS and Kernel ----
echo "[System]"
KERNEL_VERSION=$(uname -r)
write_version "KERNEL" "${KERNEL_VERSION}"

OS_VERSION=$(. /etc/os-release 2>/dev/null && echo "${ID}${VERSION_ID}" || true)
write_version "OS" "${OS_VERSION}"

# ---- CMAKE ----
echo "[CMake]"
CMAKE_VERSION=$(cmake --version 2>/dev/null | head -1 | awk '{print $3}' || true)
write_version "CMAKE" "${CMAKE_VERSION}"

# ---- DOCA / OFED ----
echo "[DOCA/OFED]"
if command -v ofed_info &>/dev/null; then
    OFED_RAW=$(ofed_info -n 2>/dev/null || true)
    # ofed_info -n returns something like "25.10-OFED.25.10.0.2.8.1" or "MLNX_OFED_LINUX-24.10..."
    OFED_VERSION="${OFED_RAW}"
    write_version "OFED" "${OFED_VERSION}"
fi

# DOCA version: check dpkg or rpm
DOCA_VERSION=""
if command -v dpkg-query &>/dev/null; then
    DOCA_VERSION=$(dpkg-query -W -f='${Version}' doca-runtime 2>/dev/null | sed 's/-.*//' || true)
fi
if [[ -z "${DOCA_VERSION}" ]] && command -v rpm &>/dev/null; then
    DOCA_VERSION=$(rpm -q --qf '%{VERSION}' doca-runtime 2>/dev/null || true)
    [[ "${DOCA_VERSION}" == *"not installed"* ]] && DOCA_VERSION=""
fi
write_version "DOCA" "${DOCA_VERSION}"

# ---- PMIx ----
echo "[PMIx]"
PMIX_VERSION=""
if command -v pmix_info &>/dev/null; then
    PMIX_VERSION=$(pmix_info --pretty-print 2>/dev/null | grep "PMIx:" | head -1 | awk '{print $NF}' || true)
fi
if [[ -z "${PMIX_VERSION}" ]]; then
    # Try pkg-config
    PMIX_VERSION=$(pkg-config --modversion pmix 2>/dev/null || true)
fi
write_version "PMIX" "${PMIX_VERSION}"

# ---- MPI: HPC-X ----
echo "[MPI Libraries]"
HPCX_VERSION=""
# HPC-X is usually installed under /opt/hpcx-*
HPCX_DIR=$(ls -d /opt/hpcx-v* 2>/dev/null | sort -V | tail -1 || true)
if [[ -n "${HPCX_DIR}" ]]; then
    HPCX_VERSION=$(basename "${HPCX_DIR}" | sed 's/^hpcx-v//' | sed 's/-gcc.*//')
fi
write_version "HPCX" "${HPCX_VERSION}"

# ---- MPI: MVAPICH / MVAPICH2 ----
MVAPICH_VERSION=""
MVAPICH_DIR=$(ls -d /opt/mvapich2-* 2>/dev/null | sort -V | tail -1 || true)
if [[ -n "${MVAPICH_DIR}" ]]; then
    MVAPICH_VERSION=$(basename "${MVAPICH_DIR}" | sed 's/^mvapich2-//')
fi
if [[ -n "${MVAPICH_VERSION}" ]]; then
    write_version "MVAPICH2" "${MVAPICH_VERSION}"
else
    MVAPICH_DIR=$(ls -d /opt/mvapich-* 2>/dev/null | sort -V | tail -1 || true)
    if [[ -n "${MVAPICH_DIR}" ]]; then
        MVAPICH_VERSION=$(basename "${MVAPICH_DIR}" | sed 's/^mvapich-//')
        write_version "MVAPICH" "${MVAPICH_VERSION}"
    fi
fi

# ---- MPI: Open MPI ----
OMPI_VERSION=""
OMPI_DIR=$(ls -d /opt/openmpi-* 2>/dev/null | sort -V | tail -1 || true)
if [[ -n "${OMPI_DIR}" ]]; then
    OMPI_VERSION=$(basename "${OMPI_DIR}" | sed 's/^openmpi-//')
fi
write_version "OMPI" "${OMPI_VERSION}"

# ---- MPI: Intel MPI ----
IMPI_VERSION=""
# Intel MPI is typically under /opt/intel/compilers_and_libraries_*/linux/mpi or modulefiles
if [ -d /opt/intel ]; then
    # Try to find from modulefile or directory name
    IMPI_DIR=$(ls -d /opt/intel/oneapi/mpi/* 2>/dev/null | sort -V | tail -1 || true)
    if [[ -n "${IMPI_DIR}" ]]; then
        IMPI_VERSION=$(basename "${IMPI_DIR}")
    fi
fi
write_version "IMPI" "${IMPI_VERSION}"

# ---- mpiFileUtils ----
echo "[mpiFileUtils]"
MPIFILEUTILS_VERSION=""
if command -v dbcast &>/dev/null; then
    # mpifileutils doesn't always have --version; check the install path
    MFU_DIR=$(ls -d /opt/mpifileutils-* 2>/dev/null | sort -V | tail -1 || true)
    if [[ -n "${MFU_DIR}" ]]; then
        MPIFILEUTILS_VERSION=$(basename "${MFU_DIR}" | sed 's/^mpifileutils-//')
    fi
fi
write_version "MPIFILEUTILS" "${MPIFILEUTILS_VERSION}"

# ---- NVIDIA Components ----
if [[ "${GPU_PLATFORM}" == "NVIDIA" ]]; then
    echo "[NVIDIA GPU Stack]"
    
    # NVIDIA driver
    NVIDIA_VERSION=""
    if command -v nvidia-smi &>/dev/null; then
        NVIDIA_VERSION=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -1 || true)
    fi
    write_version "NVIDIA" "${NVIDIA_VERSION}"
    
    # CUDA
    CUDA_VERSION=""
    if command -v nvcc &>/dev/null; then
        CUDA_VERSION=$(nvcc --version 2>/dev/null | grep "release" | awk '{print $5}' | sed 's/,//' || true)
    elif [ -f /usr/local/cuda/version.txt ]; then
        CUDA_VERSION=$(cat /usr/local/cuda/version.txt | awk '{print $3}' || true)
    elif [ -L /usr/local/cuda ]; then
        CUDA_VERSION=$(readlink /usr/local/cuda | sed 's/.*cuda-//' || true)
    fi
    write_version "CUDA" "${CUDA_VERSION}"
    
    # NCCL
    NCCL_VERSION=""
    if command -v dpkg-query &>/dev/null; then
        NCCL_VERSION=$(dpkg-query -W -f='${Version}' libnccl2 2>/dev/null | sed 's/+.*//' || true)
    fi
    if [[ -z "${NCCL_VERSION}" ]] && command -v rpm &>/dev/null; then
        NCCL_VERSION=$(rpm -q --qf '%{VERSION}' libnccl 2>/dev/null || true)
        [[ "${NCCL_VERSION}" == *"not installed"* ]] && NCCL_VERSION=""
    fi
    write_version "NCCL" "${NCCL_VERSION}"
    
    # NVIDIA Fabric Manager
    NFM_VERSION=""
    if command -v nv-fabricmanager &>/dev/null; then
        NFM_VERSION=$(nv-fabricmanager --version 2>/dev/null | grep -oP '[\d]+\.[\d]+\.[\d]+[\.\d]*' | head -1 || true)
    fi
    if [[ -z "${NFM_VERSION}" ]]; then
        if command -v dpkg-query &>/dev/null; then
            NFM_VERSION=$(dpkg-query -W -f='${Version}' nvidia-fabricmanager-* 2>/dev/null | head -1 | sed 's/-.*//' || true)
        fi
        if [[ -z "${NFM_VERSION}" ]] && command -v rpm &>/dev/null; then
            NFM_VERSION=$(rpm -qa 'nvidia-fabricmanager*' --qf '%{VERSION}\n' 2>/dev/null | head -1 || true)
        fi
    fi
    write_version "NVIDIA_FABRIC_MANAGER" "${NFM_VERSION}"

    # IMEX (only on GB200)
    IMEX_VERSION=""
    if command -v dpkg-query &>/dev/null; then
        IMEX_VERSION=$(dpkg-query -W -f='${Version}' nvidia-imex-* 2>/dev/null | head -1 | sed 's/-.*//' || true)
    fi
    write_version "IMEX" "${IMEX_VERSION}"
    
    # DCGM
    echo "[DCGM]"
    DCGM_VERSION=""
    if command -v dcgmi &>/dev/null; then
        DCGM_VERSION=$(dcgmi --version 2>/dev/null | awk '{print $3}' | head -1 || true)
    fi
    write_version "DCGM" "${DCGM_VERSION}"
    
    # GDRCopy
    echo "[GDRCopy]"
    GDRCOPY_VERSION=""
    if command -v dpkg-query &>/dev/null; then
        GDRCOPY_VERSION=$(dpkg-query -W -f='${Version}' gdrcopy 2>/dev/null | sed 's/-.*//' || true)
        [[ -z "${GDRCOPY_VERSION}" ]] && GDRCOPY_VERSION=$(dpkg-query -W -f='${Version}' gdrcopy-tools 2>/dev/null | sed 's/-.*//' || true)
    fi
    if [[ -z "${GDRCOPY_VERSION}" ]] && command -v rpm &>/dev/null; then
        GDRCOPY_VERSION=$(rpm -q --qf '%{VERSION}' gdrcopy 2>/dev/null || true)
        [[ "${GDRCOPY_VERSION}" == *"not installed"* ]] && GDRCOPY_VERSION=""
    fi
    write_version "GDRCOPY" "${GDRCOPY_VERSION}"
    
    # Docker / Moby Engine
    echo "[Container Runtime]"
    DOCKER_VERSION=""
    if command -v docker &>/dev/null; then
        DOCKER_VERSION=$(docker --version 2>/dev/null | awk '{print $3}' | sed 's/,//' || true)
    fi
    write_version "DOCKER" "${DOCKER_VERSION}"
    
    MOBY_VERSION=""
    if command -v dpkg-query &>/dev/null; then
        MOBY_VERSION=$(dpkg-query -W -f='${Version}' moby-engine 2>/dev/null | sed 's/-.*//' || true)
    fi
    if [[ -z "${MOBY_VERSION}" ]] && command -v rpm &>/dev/null; then
        MOBY_VERSION=$(rpm -q --qf '%{VERSION}' moby-engine 2>/dev/null || true)
        [[ "${MOBY_VERSION}" == *"not installed"* ]] && MOBY_VERSION=""
    fi
    write_version "MOBY_ENGINE" "${MOBY_VERSION}"
    
    # NVIDIA Container Toolkit
    NCTK_VERSION=""
    if command -v nvidia-container-toolkit &>/dev/null; then
        NCTK_VERSION=$(nvidia-container-toolkit --version 2>/dev/null | awk '{print $NF}' || true)
    fi
    write_version "NVIDIA_CONTAINER_TOOLKIT" "${NCTK_VERSION}"
    
    # NVBandwidth
    echo "[NVBandwidth]"
    NVBANDWIDTH_VERSION=""
    if command -v nvbandwidth &>/dev/null; then
        NVBANDWIDTH_VERSION=$(nvbandwidth --version 2>/dev/null | head -1 | awk '{print $NF}' || true)
    fi
    write_version "NVBANDWIDTH" "${NVBANDWIDTH_VERSION}"

    # NVSHMEM
    echo "[NVSHMEM]"
    NVSHMEM_VERSION=""
    NVSHMEM_DIR=$(ls -d /opt/nvshmem* 2>/dev/null | sort -V | tail -1 || true)
    if [[ -n "${NVSHMEM_DIR}" ]]; then
        NVSHMEM_VERSION=$(basename "${NVSHMEM_DIR}" | sed 's/^nvshmem_//' | sed 's/^nvshmem-//')
    fi
    write_version "NVSHMEM" "${NVSHMEM_VERSION}"

    # NVLOOM
    echo "[NVLOOM]"
    NVLOOM_VERSION=""
    NVLOOM_DIR=$(ls -d /opt/nvloom* 2>/dev/null | sort -V | tail -1 || true)
    if [[ -n "${NVLOOM_DIR}" ]]; then
        NVLOOM_VERSION=$(basename "${NVLOOM_DIR}" | sed 's/^nvloom-//')
    fi
    write_version "NVLOOM" "${NVLOOM_VERSION}"
fi

# ---- AMD Components ----
if [[ "${GPU_PLATFORM}" == "AMD" ]]; then
    echo "[AMD GPU Stack]"
    
    # ROCm
    ROCM_VERSION=""
    if [ -f /opt/rocm/.info/version ]; then
        ROCM_VERSION=$(cat /opt/rocm/.info/version 2>/dev/null || true)
    elif command -v rocminfo &>/dev/null; then
        ROCM_VERSION=$(rocminfo 2>/dev/null | grep "Runtime Version" | awk '{print $NF}' || true)
    fi
    write_version "ROCM" "${ROCM_VERSION}"
    
    # RCCL
    RCCL_VERSION=""
    RCCL_DIR=$(ls -d /opt/rccl* 2>/dev/null | sort -V | tail -1 || true)
    if [[ -n "${RCCL_DIR}" ]]; then
        RCCL_VERSION=$(basename "${RCCL_DIR}" | sed 's/^rccl-//')
    fi
    write_version "RCCL" "${RCCL_VERSION}"
    
    # AOCL — installed by install_amd_libs.sh, which flattens lib/include into
    # /opt/amd and carries the version only in the modulefile name.
    AOCL_VERSION=""
    AOCL_MODULEFILE=$(ls -1 \
        /usr/share/modules/modulefiles/amd/aocl-* \
        /usr/share/Modules/modulefiles/amd/aocl-* \
        2>/dev/null | grep -v '/aocl$' | sort -V | tail -1 || true)
    if [[ -n "${AOCL_MODULEFILE}" ]]; then
        AOCL_VERSION=$(basename "${AOCL_MODULEFILE}" | sed 's/^aocl-//')
    fi
    write_version "AOCL" "${AOCL_VERSION}"

    # AOCC — installed under /opt/amd/aocc-compiler-<version>/ by
    # install_amd_libs.sh (INSTALL_PREFIX=/opt/amd, lowercase).
    AOCC_VERSION=""
    AOCC_DIR=$(ls -d /opt/amd/aocc-compiler-* /opt/AMD/aocc-compiler-* 2>/dev/null | sort -V | tail -1 || true)
    if [[ -n "${AOCC_DIR}" ]]; then
        AOCC_VERSION=$(basename "${AOCC_DIR}" | sed 's/^aocc-compiler-//')
    fi
    write_version "AOCC" "${AOCC_VERSION}"
fi

# ---- Intel MKL ----
echo "[Intel Libraries]"
INTEL_MKL_VERSION=""
if [ -d /opt/intel/oneapi/mkl ]; then
    MKL_DIR=$(ls -d /opt/intel/oneapi/mkl/* 2>/dev/null | sort -V | tail -1 || true)
    if [[ -n "${MKL_DIR}" && "$(basename "${MKL_DIR}")" != "latest" ]]; then
        INTEL_MKL_VERSION=$(basename "${MKL_DIR}")
    fi
fi
write_version "INTEL_ONE_MKL" "${INTEL_MKL_VERSION}"

# ---- Lustre ----
echo "[Lustre]"
LUSTRE_VERSION=""
if command -v lfs &>/dev/null; then
    LUSTRE_VERSION=$(lfs --version 2>/dev/null | awk '{print $2}' || true)
fi
write_version "LUSTRE" "${LUSTRE_VERSION}"

# ---- dynolog / dyno_relay_logger ----
echo "[Dynolog]"
DYNOLOG_VERSION=""
if command -v dynolog &>/dev/null; then
    # dynolog might not have --version, check package
    if command -v dpkg-query &>/dev/null; then
        DYNOLOG_VERSION=$(dpkg-query -W -f='${Version}' dynolog 2>/dev/null | sed 's/-.*//' || true)
    fi
    if [[ -z "${DYNOLOG_VERSION}" ]] && command -v rpm &>/dev/null; then
        DYNOLOG_VERSION=$(rpm -q --qf '%{VERSION}' dynolog 2>/dev/null || true)
        [[ "${DYNOLOG_VERSION}" == *"not installed"* ]] && DYNOLOG_VERSION=""
    fi
fi
write_version "dynolog" "${DYNOLOG_VERSION}"

DRL_VERSION=""
if command -v dyno_relay_logger &>/dev/null; then
    DRL_VERSION=$(dyno_relay_logger --version 2>/dev/null | head -1 | awk '{print $NF}' || true)
fi
write_version "dyno_relay_logger" "${DRL_VERSION}"

# ---- Monitoring Tools (Moneo) ----
echo "[Monitoring]"
MONEO_VERSION=""
if [ -d /opt/azurehpc/tools/Moneo ]; then
    if [ -f /opt/azurehpc/tools/Moneo/version.txt ]; then
        MONEO_VERSION=$(cat /opt/azurehpc/tools/Moneo/version.txt 2>/dev/null || true)
    fi
fi
write_version "MONEO" "${MONEO_VERSION}"

# ---- Azure Health Checks ----
echo "[Health Checks]"
AZHC_VERSION=""
if [ -d /opt/azurehpc/test/azurehpc-health-checks ]; then
    if [ -f /opt/azurehpc/test/azurehpc-health-checks/version.txt ]; then
        AZHC_VERSION=$(cat /opt/azurehpc/test/azurehpc-health-checks/version.txt 2>/dev/null || true)
    fi
fi
write_version "AZ_HEALTH_CHECKS" "${AZHC_VERSION}"

# ---- WAAgent ----
echo "[WAAgent]"
WAAGENT_VERSION=""
WAAGENT_EXT_VERSION=""
if command -v waagent &>/dev/null; then
    WAAGENT_VERSION=$(waagent --version 2>/dev/null | head -n 1 | awk -F' ' '{print $1}' | awk -F- '{print $2}' || true)
    WAAGENT_EXT_VERSION=$(waagent --version 2>/dev/null | sed '3q;d' | awk -F' ' '{print $4}' || true)
elif command -v python3.12 &>/dev/null && [ -f /usr/sbin/waagent ]; then
    WAAGENT_VERSION=$(python3.12 -u /usr/sbin/waagent --version 2>/dev/null | head -n 1 | awk -F' ' '{print $1}' | awk -F- '{print $2}' || true)
    WAAGENT_EXT_VERSION=$(python3.12 -u /usr/sbin/waagent --version 2>/dev/null | sed '3q;d' | awk -F' ' '{print $4}' || true)
fi
write_version "WAAGENT" "${WAAGENT_VERSION}"
write_version "WAAGENT_EXTENSIONS" "${WAAGENT_EXT_VERSION}"

# ---- Restore ImageVersion if it was set ----
if [[ -n "${EXISTING_IMAGE_VERSION:-}" ]]; then
    echo ""
    echo "[Preserving previous ImageVersion: ${EXISTING_IMAGE_VERSION}]"
    write_component_version "ImageVersion" "${EXISTING_IMAGE_VERSION}"
fi

echo ""
echo "=== component_versions.txt refresh complete ==="
echo "Output: ${COMPONENT_VERSIONS_FILE}"
echo ""
echo "Contents:"
cat "${COMPONENT_VERSIONS_FILE}"
