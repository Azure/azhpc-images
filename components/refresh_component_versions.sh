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

# Refresh is non-destructive: existing entries (written by install_*.sh via
# write_component_version) are preserved unless we successfully re-detect a
# component from the system. This matters for components whose version
# cannot be queried without GPU/IB hardware (e.g. NVBANDWIDTH, NVLOOM) when
# the build runs on a general-purpose SKU — the value written at install
# time stays in the manifest. The write_version helper below skips empty
# detections, so undetected components simply retain their previous entry.
if [ ! -f "${COMPONENT_VERSIONS_FILE}" ]; then
    echo '{}' > "${COMPONENT_VERSIONS_FILE}"
fi

# Helper: write version only if non-empty
write_version() {
    local component="$1"
    local version="$2"
    if [[ -n "${version}" && "${version}" != "null" ]]; then
        write_component_version "${component}" "${version}"
        echo "  [OK] ${component} = ${version}"
    else
        echo "  [--] ${component} not detected (keeping existing entry, if any)"
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
# Intel MPI installs to /opt/intel/oneapi/mpi/<version>/ with a 'latest'
# symlink alongside the versioned directory. Exclude symlinks (including
# 'latest') so we pick the real versioned directory; otherwise sort -V
# would happily return 'latest' (letters sort after digits).
if [ -d /opt/intel/oneapi/mpi ]; then
    IMPI_DIR=$(find /opt/intel/oneapi/mpi -mindepth 1 -maxdepth 1 -type d ! -name latest 2>/dev/null \
        | sort -V | tail -1 || true)
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
    # Avoid nvidia-smi here — it requires GPU hardware and fails on
    # general-purpose build SKUs. Read the version directly from the kernel
    # module metadata (modinfo works on the .ko file without loading it and
    # without any GPU present); fall back to /sys (only if the module is
    # loaded) and finally to package-manager queries.
    NVIDIA_VERSION=""
    if command -v modinfo &>/dev/null; then
        NVIDIA_VERSION=$(modinfo nvidia 2>/dev/null | awk '/^version:/{print $2; exit}' || true)
        # If 'modinfo nvidia' can't resolve via depmod's index (e.g. depmod
        # wasn't refreshed), point modinfo directly at the .ko file.
        if [[ -z "${NVIDIA_VERSION}" ]]; then
            NVIDIA_KO=$(find /lib/modules -type f \( -name 'nvidia.ko' -o -name 'nvidia.ko.xz' -o -name 'nvidia.ko.zst' -o -name 'nvidia.ko.gz' \) 2>/dev/null | head -1)
            if [[ -n "${NVIDIA_KO}" ]]; then
                NVIDIA_VERSION=$(modinfo -F version "${NVIDIA_KO}" 2>/dev/null || true)
            fi
        fi
    fi
    if [[ -z "${NVIDIA_VERSION}" && -r /sys/module/nvidia/version ]]; then
        NVIDIA_VERSION=$(cat /sys/module/nvidia/version 2>/dev/null || true)
    fi
    if [[ -z "${NVIDIA_VERSION}" ]] && command -v dpkg-query &>/dev/null; then
        # Try the open / proprietary driver packages and the cuda-drivers
        # metapackage in turn. nvidia-driver-* (proprietary) and nvidia-open-*
        # both carry the driver version as the deb upstream version.
        for pkg_pattern in 'nvidia-open-[0-9]*' 'nvidia-driver-[0-9]*' 'cuda-drivers'; do
            NVIDIA_VERSION=$(dpkg-query -W -f='${Version}\n' "${pkg_pattern}" 2>/dev/null \
                | head -1 | sed 's/-.*//' || true)
            [[ -n "${NVIDIA_VERSION}" ]] && break
        done
    fi
    if [[ -z "${NVIDIA_VERSION}" ]] && command -v rpm &>/dev/null; then
        NVIDIA_VERSION=$(rpm -qa 'nvidia-driver*' --qf '%{VERSION}\n' 2>/dev/null \
            | sort -V | tail -1 || true)
        # Last resort: cuda-drivers metapackage (RPM-based AzureLinux/RHEL).
        if [[ -z "${NVIDIA_VERSION}" ]]; then
            NVIDIA_VERSION=$(rpm -q --qf '%{VERSION}' cuda-drivers 2>/dev/null || true)
            [[ "${NVIDIA_VERSION}" == *"not installed"* ]] && NVIDIA_VERSION=""
        fi
    fi
    write_version "NVIDIA" "${NVIDIA_VERSION}"
    
    # CUDA
    # Order of preference (most precise first):
    #   1. /usr/local/cuda/version.json — modern CUDA (>=11) ships the full
    #      patch version here (e.g. "13.0.88").
    #   2. nvcc --version — parse the "V<X.Y.Z>" build string for the full
    #      patch version. nvcc isn't always on PATH for non-login shells,
    #      so call /usr/local/cuda/bin/nvcc directly.
    #   3. /usr/local/cuda/version.txt — legacy CUDA (<11).
    #   4. readlink -f /usr/local/cuda — follow the full alternatives chain
    #      (/usr/local/cuda -> /etc/alternatives/cuda -> /usr/local/cuda-X.Y)
    #      and use the leaf directory name. This only carries major.minor.
    CUDA_VERSION=""
    if [ -f /usr/local/cuda/version.json ]; then
        if command -v jq &>/dev/null; then
            CUDA_VERSION=$(jq -r '.cuda.version // empty' /usr/local/cuda/version.json 2>/dev/null || true)
        fi
        if [[ -z "${CUDA_VERSION}" ]]; then
            # jq missing or absent key — fall back to a minimal grep/sed.
            CUDA_VERSION=$(grep -A2 '"cuda"' /usr/local/cuda/version.json 2>/dev/null \
                | sed -nE 's/.*"version"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' \
                | head -1 || true)
        fi
    fi
    if [[ -z "${CUDA_VERSION}" ]]; then
        NVCC_BIN=""
        if command -v nvcc &>/dev/null; then
            NVCC_BIN="nvcc"
        elif [ -x /usr/local/cuda/bin/nvcc ]; then
            NVCC_BIN="/usr/local/cuda/bin/nvcc"
        fi
        if [[ -n "${NVCC_BIN}" ]]; then
            # Prefer the precise "V<X.Y.Z>" token over "release X.Y".
            CUDA_VERSION=$("${NVCC_BIN}" --version 2>/dev/null \
                | sed -nE 's/.*[, ]V([0-9][0-9.]*).*/\1/p' | head -1 || true)
            if [[ -z "${CUDA_VERSION}" ]]; then
                CUDA_VERSION=$("${NVCC_BIN}" --version 2>/dev/null \
                    | grep "release" | awk '{print $5}' | sed 's/,//' || true)
            fi
        fi
    fi
    if [[ -z "${CUDA_VERSION}" ]] && [ -f /usr/local/cuda/version.txt ]; then
        CUDA_VERSION=$(awk '{print $3}' /usr/local/cuda/version.txt 2>/dev/null || true)
    fi
    if [[ -z "${CUDA_VERSION}" ]] && [ -e /usr/local/cuda ]; then
        # readlink -f follows the entire alternatives chain to the real dir.
        CUDA_REAL=$(readlink -f /usr/local/cuda 2>/dev/null || true)
        if [[ -n "${CUDA_REAL}" ]]; then
            CUDA_VERSION=$(basename "${CUDA_REAL}" | sed -nE 's/^cuda-?([0-9][0-9.]*)$/\1/p' || true)
        fi
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
    # Prefer package-manager metadata: it works on general-purpose build SKUs
    # (no NVSwitch hardware), is unaffected by whether the fabricmanager
    # service can start, and matches install_nvidia_fabric_manager.sh which
    # also reads the version from dpkg. Keep the full Debian/RPM version
    # string (including '-<revision>') so it round-trips with what the
    # install script wrote (e.g. '580.126.16-1').
    NFM_VERSION=""
    if command -v dpkg-query &>/dev/null; then
        NFM_VERSION=$(dpkg-query -W -f='${Version}\n' 'nvidia-fabricmanager-*' 'nvidia-fabricmanager' 2>/dev/null \
            | head -1 || true)
    fi
    if [[ -z "${NFM_VERSION}" ]] && command -v rpm &>/dev/null; then
        NFM_VERSION=$(rpm -qa 'nvidia-fabric-manager*' 'nvidia-fabricmanager*' --qf '%{VERSION}-%{RELEASE}\n' 2>/dev/null \
            | sort -V | tail -1 || true)
    fi
    # Last resort: ask the binary itself. nv-fabricmanager --version prints
    # without contacting hardware, so it normally works even on a general SKU,
    # but only if the package is actually present.
    if [[ -z "${NFM_VERSION}" ]] && command -v nv-fabricmanager &>/dev/null; then
        NFM_VERSION=$(nv-fabricmanager --version 2>/dev/null | grep -oP '[\d]+\.[\d]+\.[\d]+[\.\d]*' | head -1 || true)
    fi
    write_version "NVIDIA_FABRIC_MANAGER" "${NFM_VERSION}"

    # IMEX (only on GB200)
    IMEX_VERSION=""
    if command -v dpkg-query &>/dev/null; then
        IMEX_VERSION=$(dpkg-query -W -f='${Version}' nvidia-imex-* 2>/dev/null | head -1 | sed 's/-.*//' || true)
    fi
    write_version "IMEX" "${IMEX_VERSION}"
    
    # DCGM
    # Prefer package-manager metadata: `dcgmi --version` normally prints
    # without GPU but may behave inconsistently across releases, and it is
    # not present on systems where only the daemon package is installed.
    # Keep the full version string (with epoch '1:' and Debian '-<rev>'
    # suffix) so it matches install_dcgm.sh's write_component_version call
    # (e.g. '1:4.5.2-1').
    echo "[DCGM]"
    DCGM_VERSION=""
    if command -v dpkg-query &>/dev/null; then
        DCGM_VERSION=$(dpkg-query -W -f='${Version}\n' \
            'datacenter-gpu-manager-4-core' 'datacenter-gpu-manager-4-cuda*' \
            'datacenter-gpu-manager' 2>/dev/null \
            | head -1 || true)
    fi
    if [[ -z "${DCGM_VERSION}" ]] && command -v rpm &>/dev/null; then
        DCGM_VERSION=$(rpm -qa 'datacenter-gpu-manager-4-cuda*' 'datacenter-gpu-manager*' --qf '%{VERSION}-%{RELEASE}\n' 2>/dev/null \
            | sort -V | tail -1 || true)
    fi
    if [[ -z "${DCGM_VERSION}" ]] && command -v dcgmi &>/dev/null; then
        DCGM_VERSION=$(dcgmi --version 2>/dev/null | awk '{print $3}' | head -1 || true)
    fi
    write_version "DCGM" "${DCGM_VERSION}"
    
    # GDRCopy
    # Keep the full Debian/RPM version string so the entry matches what
    # install_gdrcopy.sh writes (e.g. '2.5.2-1' from versions.json).
    echo "[GDRCopy]"
    GDRCOPY_VERSION=""
    if command -v dpkg-query &>/dev/null; then
        GDRCOPY_VERSION=$(dpkg-query -W -f='${Version}' gdrcopy 2>/dev/null || true)
        [[ -z "${GDRCOPY_VERSION}" ]] && GDRCOPY_VERSION=$(dpkg-query -W -f='${Version}' gdrcopy-tools 2>/dev/null || true)
    fi
    if [[ -z "${GDRCOPY_VERSION}" ]] && command -v rpm &>/dev/null; then
        GDRCOPY_VERSION=$(rpm -q --qf '%{VERSION}-%{RELEASE}' gdrcopy 2>/dev/null || true)
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
    # Keep the full Debian/RPM version string (including '-ubuntu24.04u1'
    # or '-<release>' suffix) so it round-trips with install_docker.sh's
    # `apt list --installed` output, e.g. '29.4.3-ubuntu24.04u1'.
    if command -v dpkg-query &>/dev/null; then
        MOBY_VERSION=$(dpkg-query -W -f='${Version}' moby-engine 2>/dev/null || true)
    fi
    if [[ -z "${MOBY_VERSION}" ]] && command -v rpm &>/dev/null; then
        MOBY_VERSION=$(rpm -q --qf '%{VERSION}-%{RELEASE}' moby-engine 2>/dev/null || true)
        [[ "${MOBY_VERSION}" == *"not installed"* ]] && MOBY_VERSION=""
    fi
    write_version "MOBY_ENGINE" "${MOBY_VERSION}"
    
    # NVIDIA Container Toolkit
    # `nvidia-container-toolkit --version` prints two lines:
    #   NVIDIA Container Runtime Hook version <X.Y.Z>
    #   commit: <sha>
    # We want only the version on the first line; take head -1 first so
    # awk doesn't emit a value per line (which would embed a newline in
    # the JSON manifest).
    NCTK_VERSION=""
    if command -v nvidia-container-toolkit &>/dev/null; then
        NCTK_VERSION=$(nvidia-container-toolkit --version 2>/dev/null | head -1 | awk '{print $NF}' || true)
    fi
    write_version "NVIDIA_CONTAINER_TOOLKIT" "${NCTK_VERSION}"
    
    # NVBandwidth
    # The nvbandwidth binary is installed to /opt/nvidia/nvbandwidth/ and is
    # not on PATH. Running `nvbandwidth --version` initializes CUDA on entry,
    # so it fails on general-purpose build SKUs that have no GPU. There is
    # also no version metadata on disk to read. Refresh is non-destructive,
    # so on a general SKU the entry written at install time by
    # install_nvbandwidth_tool.sh is retained as the source of truth.
    echo "[NVBandwidth]"
    NVBANDWIDTH_VERSION=""
    if [ -x /opt/nvidia/nvbandwidth/nvbandwidth ]; then
        # Best-effort: only succeeds when a GPU is present.
        NVBANDWIDTH_VERSION=$(/opt/nvidia/nvbandwidth/nvbandwidth --version 2>/dev/null | head -1 | awk '{print $NF}' || true)
    fi
    write_version "NVBANDWIDTH" "${NVBANDWIDTH_VERSION}"

    # NVSHMEM
    # Installed as the libnvshmem3-cuda-<MAJOR> package (apt/tdnf) by
    # install_nvshmem.sh — there is no /opt path to inspect.
    echo "[NVSHMEM]"
    NVSHMEM_VERSION=""
    if command -v dpkg-query &>/dev/null; then
        NVSHMEM_VERSION=$(dpkg-query -W -f='${Version}\n' 'libnvshmem3-cuda-*' 2>/dev/null \
            | sort -V | tail -1 | sed 's/+.*//' || true)
    fi
    if [[ -z "${NVSHMEM_VERSION}" ]] && command -v rpm &>/dev/null; then
        NVSHMEM_VERSION=$(rpm -qa 'libnvshmem3-cuda-*' --qf '%{VERSION}\n' 2>/dev/null \
            | sort -V | tail -1 || true)
    fi
    write_version "NVSHMEM" "${NVSHMEM_VERSION}"

    # NVLOOM
    # install_nvloom.sh leaves no version metadata on disk and the binary
    # cannot self-report without GPU/MPI. Refresh is non-destructive, so the
    # entry written by install_nvloom.sh is retained on general SKUs.
    echo "[NVLOOM]"
    write_version "NVLOOM" ""
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
fi

# ---- AMD CPU compilers / libs (installed on x86_64 for BOTH NVIDIA and AMD
# GPU builds via components/install_amd_libs.sh) ----
echo "[AMD CPU Libraries]"

# AOCL — install_amd_libs.sh flattens lib/include into /opt/amd; the version
# is preserved only in the modulefile name (e.g. amd/aocl-5.1.0).
AOCL_VERSION=""
AOCL_MODULEFILE=$(ls -1 \
    /usr/share/modules/modulefiles/amd/aocl-* \
    /usr/share/Modules/modulefiles/amd/aocl-* \
    2>/dev/null | grep -v '/aocl$' | sort -V | tail -1 || true)
if [[ -n "${AOCL_MODULEFILE}" ]]; then
    AOCL_VERSION=$(basename "${AOCL_MODULEFILE}" | sed 's/^aocl-//')
fi
write_version "AOCL" "${AOCL_VERSION}"

# AOCC — install_amd_libs.sh copies the extracted folder to
# /opt/amd/aocc-compiler-<version>/.  Some legacy images use uppercase
# /opt/AMD/aocc-compiler-<version>/ (AMD installer default), so check both.
AOCC_VERSION=""
AOCC_DIR=$(ls -d /opt/amd/aocc-compiler-* /opt/AMD/aocc-compiler-* 2>/dev/null | sort -V | tail -1 || true)
if [[ -n "${AOCC_DIR}" ]]; then
    AOCC_VERSION=$(basename "${AOCC_DIR}" | sed 's/^aocc-compiler-//')
fi
# Last-resort fallback: query the installed clang binary that ships with AOCC.
if [[ -z "${AOCC_VERSION}" ]]; then
    for clang_bin in /opt/amd/aocc-compiler-*/bin/clang /opt/AMD/aocc-compiler-*/bin/clang; do
        if [[ -x "${clang_bin}" ]]; then
            AOCC_VERSION=$("${clang_bin}" --version 2>/dev/null \
                | sed -nE 's/.*AOCC[_ ]([0-9][0-9.]*).*/\1/p' | head -1 || true)
            [[ -n "${AOCC_VERSION}" ]] && break
        fi
    done
fi
write_version "AOCC" "${AOCC_VERSION}"

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
# Prefer package-manager metadata so the refreshed value round-trips with
# install_lustre_client.sh: on Ubuntu+build-from-source it writes the
# dpkg ${Version} of lustre-client-utils (e.g. '2.16.1-17-g43573dd-1'),
# on Ubuntu+repo it writes the amlfs-lustre-client-* version, and on RHEL
# it writes the underscore-form package version. `lfs --version` only
# returns the build's internal version string (underscores, no Debian
# revision), so it's a last-resort fallback.
echo "[Lustre]"
LUSTRE_VERSION=""
if command -v dpkg-query &>/dev/null; then
    # Build-from-source path installs lustre-client-utils.
    LUSTRE_VERSION=$(dpkg-query -W -f='${Version}\n' lustre-client-utils 2>/dev/null \
        | head -1 | cut -d'~' -f1 || true)
    # Repo path installs amlfs-lustre-client-<kernel-suffix>.
    if [[ -z "${LUSTRE_VERSION}" ]]; then
        LUSTRE_VERSION=$(dpkg-query -W -f='${Version}\n' 'amlfs-lustre-client-*' 2>/dev/null \
            | head -1 | cut -d'~' -f1 || true)
    fi
fi
if [[ -z "${LUSTRE_VERSION}" ]] && command -v rpm &>/dev/null; then
    LUSTRE_VERSION=$(rpm -qa 'amlfs-lustre-client-*' 'lustre-client*' --qf '%{VERSION}-%{RELEASE}\n' 2>/dev/null \
        | head -1 || true)
fi
if [[ -z "${LUSTRE_VERSION}" ]] && command -v lfs &>/dev/null; then
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

echo ""
echo "=== component_versions.txt refresh complete ==="
echo "Output: ${COMPONENT_VERSIONS_FILE}"
echo ""
echo "Contents:"
cat "${COMPONENT_VERSIONS_FILE}"
