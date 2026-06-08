#!/bin/bash
set -euo pipefail

# =============================================================================
# Refresh Component Versions
# =============================================================================
# Regenerates /opt/azurehpc/component_versions.txt by detecting installed
# versions of all HPC components on the running system.
#
# Used during "in-place refresh" builds: an existing HPC image is the base
# and only `apt update` / `apt upgrade` runs. install_*.sh scripts do NOT
# re-run, so the manifest can drift. This script rebuilds it from ground
# truth (package managers, binaries, modulefiles, etc.).
#
# Usage:
#   sudo bash refresh_component_versions.sh [GPU_PLATFORM]
#   GPU_PLATFORM: NVIDIA or AMD (default: NVIDIA)
#
# Output: /opt/azurehpc/component_versions.txt (JSON)
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/utilities.sh" || { echo "ERROR: Failed to source utilities.sh from ${SCRIPT_DIR}/../utils/"; exit 1; }

GPU_PLATFORM="${1:-NVIDIA}"
COMPONENT_VERSIONS_FILE="/opt/azurehpc/component_versions.txt"

# STRICT=1 fails the script if any REQUIRED detector returned empty.
# Default is warn-only; write_version bumps REQUIRED_MISSING per miss.
STRICT="${STRICT:-0}"
REQUIRED_MISSING=0

mkdir -p /opt/azurehpc

# Refresh is non-destructive: write_version preserves existing entries when
# detection returns empty, so components that can't be queried without
# hardware (NVBANDWIDTH, NVLOOM, ...) keep the value written at install time.
if [ ! -f "${COMPONENT_VERSIONS_FILE}" ]; then
    echo '{}' > "${COMPONENT_VERSIONS_FILE}"
fi

# Helper: write a component's version, classified by tier.
#
#   required    (default) — detector MUST succeed. Empty -> [WARN], bump
#                 REQUIRED_MISSING, fail under STRICT=1. Prior entry is
#                 still soft-preserved.
#   best-effort — detector may legitimately fail (hardware-gated, no
#                 on-disk version signal, etc). Empty is silent; the entry
#                 written by install_*.sh is the source of truth.
write_version() {
    local component="$1"
    local version="$2"
    local tier="${3:-required}"
    if [[ -n "${version}" && "${version}" != "null" ]]; then
        write_component_version "${component}" "${version}"
        echo "  [OK] ${component} = ${version}"
        return
    fi
    case "${tier}" in
        best-effort)
            echo "  [skip] ${component} (best-effort, keeping existing entry, if any)"
            ;;
        required|*)
            echo "  [WARN] ${component} REQUIRED detector returned empty; keeping existing entry, if any"
            REQUIRED_MISSING=$((REQUIRED_MISSING + 1))
            ;;
    esac
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
# install_cmake.sh drops the upstream tarball at /usr/local/bin/cmake.
# Pin the lookup there: sudo's secure_path puts /usr/bin first on RHEL,
# so any distro/EPEL cmake rpm would shadow the tarball and downgrade
# the manifest. Fall back to PATH only if the install path is missing.
echo "[CMake]"
CMAKE_VERSION=""
CMAKE_BIN=""
for candidate in /usr/local/bin/cmake /usr/bin/cmake; do
    if [ -x "${candidate}" ]; then
        CMAKE_BIN="${candidate}"
        break
    fi
done
if [[ -z "${CMAKE_BIN}" ]] && command -v cmake &>/dev/null; then
    CMAKE_BIN="$(command -v cmake)"
fi
if [[ -n "${CMAKE_BIN}" ]]; then
    CMAKE_VERSION=$("${CMAKE_BIN}" --version 2>/dev/null | head -1 | awk '{print $3}' || true)
fi
write_version "CMAKE" "${CMAKE_VERSION}"

# ---- DOCA / OFED ----
echo "[DOCA/OFED]"
if command -v ofed_info &>/dev/null; then
    OFED_RAW=$(ofed_info -n 2>/dev/null || true)
    # ofed_info -n returns something like "25.10-OFED.25.10.0.2.8.1" or "MLNX_OFED_LINUX-24.10..."
    OFED_VERSION="${OFED_RAW}"
    write_version "OFED" "${OFED_VERSION}"
fi

# DOCA: install_doca.sh installs 'doca-host' (Ubuntu, pulls doca-ofed) or
# 'doca-host'/'doca-ofed' (RPM) and writes only the leading 'X.Y.Z' from
# versions.json, so strip the '-<build>-<ofed>-<distro>' suffix to round-trip.
DOCA_VERSION=""
if command -v dpkg-query &>/dev/null; then
    DOCA_VERSION=$(dpkg-query -W -f='${Version}\n' doca-host doca-ofed doca-runtime 2>/dev/null \
        | head -1 | sed 's/-.*//' || true)
fi
if [[ -z "${DOCA_VERSION}" ]] && command -v rpm &>/dev/null; then
    DOCA_VERSION=$(rpm -qa 'doca-host' 'doca-ofed' 'doca-runtime' --qf '%{VERSION}\n' 2>/dev/null \
        | head -1 | sed 's/-.*//' || true)
fi
write_version "DOCA" "${DOCA_VERSION}"

# ---- PMIx ----
# install_pmix.sh installs the 'pmix' apt/dnf package and writes its
# version (e.g. '4.2.9-1'). Prefer package-manager metadata to round-trip;
# pmix_info/pkg-config are last-resort fallbacks (pmix_info lives in HPC-X
# and isn't on PATH; pkg-config needs libpmix-dev).
echo "[PMIx]"
PMIX_VERSION=""
if command -v dpkg-query &>/dev/null; then
    PMIX_VERSION=$(dpkg-query -W -f='${Version}\n' pmix 2>/dev/null || true)
fi
if [[ -z "${PMIX_VERSION}" ]] && command -v rpm &>/dev/null; then
    PMIX_VERSION=$(rpm -q --qf '%{VERSION}-%{RELEASE}\n' pmix 2>/dev/null || true)
    [[ "${PMIX_VERSION}" == *"not installed"* ]] && PMIX_VERSION=""
fi
# Last-resort fallbacks.
if [[ -z "${PMIX_VERSION}" ]] && command -v pmix_info &>/dev/null; then
    PMIX_VERSION=$(pmix_info --pretty-print 2>/dev/null | grep "PMIx:" | head -1 | awk '{print $NF}' || true)
fi
if [[ -z "${PMIX_VERSION}" ]]; then
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
# install_mpis.sh writes the precise marketing version (e.g. "2021.16.1"),
# but Intel oneAPI's installer truncates the on-disk path to major.minor
# (/opt/intel/oneapi/mpi/<major.minor>/) and mpirun --version reports the
# same truncated value. No on-system source carries the full version.
# /opt/intel is not apt/dnf-managed, so it can't drift across refreshes.
# Best-effort: keep the install-time entry.
IMPI_VERSION=""
write_version "IMPI" "${IMPI_VERSION}" best-effort

# ---- mpiFileUtils ----
# install_mpifileutils.sh installs to the versionless prefix
# /opt/mpifileutils/ with no on-disk version, no pkg-config, and no
# reliable CLI --version. Not apt/dnf-managed, so best-effort soft-preserve.
echo "[mpiFileUtils]"
write_version "MPIFILEUTILS" "" best-effort

# ---- NVIDIA Components ----
if [[ "${GPU_PLATFORM}" == "NVIDIA" ]]; then
    echo "[NVIDIA GPU Stack]"

    # NVIDIA driver
    # Avoid nvidia-smi: requires GPU hardware. Read the version from kernel
    # module metadata (modinfo works on the .ko without loading it or
    # needing a GPU); fall back to /sys (needs module loaded) then to
    # package-manager queries.
    NVIDIA_VERSION=""
    if command -v modinfo &>/dev/null; then
        NVIDIA_VERSION=$(modinfo nvidia 2>/dev/null | awk '/^version:/{print $2; exit}' || true)
        # If depmod's index can't resolve 'nvidia', point modinfo at the .ko.
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
        # Open / proprietary driver pkgs carry the driver version as the
        # deb upstream version; cuda-drivers metapackage as last resort.
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
    # install_nvidiagpudriver.sh writes the build/toolchain version parsed
    # from `nvcc --version` (the "V<X.Y.Z>" token, e.g. "13.0.88").
    # /usr/local/cuda/version.json carries two strings:
    #   .cuda.version — marketing version (e.g. "13.0.3")
    #   .nvcc.version — build/toolchain version (e.g. "13.0.88")
    # Prefer .nvcc.version to round-trip with install_nvidiagpudriver.sh.
    #
    # Preference order:
    #   1. version.json .nvcc.version
    #   2. nvcc --version "V<X.Y.Z>" (call by abs path; nvcc isn't on PATH
    #      for non-login shells)
    #   3. version.json .cuda.version (older toolkits may only ship this key)
    #   4. /usr/local/cuda/version.txt (legacy CUDA <11)
    #   5. /usr/local/cuda symlink target (major.minor only)
    CUDA_VERSION=""
    if [ -f /usr/local/cuda/version.json ] && command -v jq &>/dev/null; then
        # Prefer .nvcc.version (matches install_nvidiagpudriver.sh's nvcc -V parse).
        CUDA_VERSION=$(jq -r '.nvcc.version // empty' /usr/local/cuda/version.json 2>/dev/null || true)
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
    if [[ -z "${CUDA_VERSION}" ]] && [ -f /usr/local/cuda/version.json ]; then
        # Marketing version (.cuda.version) — less precise but at least M.m.p.
        if command -v jq &>/dev/null; then
            CUDA_VERSION=$(jq -r '.cuda.version // empty' /usr/local/cuda/version.json 2>/dev/null || true)
        fi
        if [[ -z "${CUDA_VERSION}" ]]; then
            # jq missing — minimal grep/sed for the "cuda" block.
            CUDA_VERSION=$(grep -A2 '"cuda"' /usr/local/cuda/version.json 2>/dev/null \
                | sed -nE 's/.*"version"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' \
                | head -1 || true)
        fi
    fi
    if [[ -z "${CUDA_VERSION}" ]] && [ -f /usr/local/cuda/version.txt ]; then
        CUDA_VERSION=$(awk '{print $3}' /usr/local/cuda/version.txt 2>/dev/null || true)
    fi
    if [[ -z "${CUDA_VERSION}" ]] && [ -e /usr/local/cuda ]; then
        # Follow alternatives chain to the real cuda-X.Y dir.
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
    # Prefer package-manager metadata: works on general SKUs, matches
    # install_nvidia_fabric_manager.sh. Keep '-<revision>' (e.g.
    # '580.126.16-1') for round-trip.
    NFM_VERSION=""
    if command -v dpkg-query &>/dev/null; then
        NFM_VERSION=$(dpkg-query -W -f='${Version}\n' 'nvidia-fabricmanager-*' 'nvidia-fabricmanager' 2>/dev/null \
            | head -1 || true)
    fi
    if [[ -z "${NFM_VERSION}" ]] && command -v rpm &>/dev/null; then
        NFM_VERSION=$(rpm -qa 'nvidia-fabric-manager*' 'nvidia-fabricmanager*' --qf '%{VERSION}-%{RELEASE}\n' 2>/dev/null \
            | sort -V | tail -1 || true)
    fi
    # Last resort: binary self-report (no hardware contact, but requires pkg).
    if [[ -z "${NFM_VERSION}" ]] && command -v nv-fabricmanager &>/dev/null; then
        NFM_VERSION=$(nv-fabricmanager --version 2>/dev/null | grep -oP '[\d]+\.[\d]+\.[\d]+[\.\d]*' | head -1 || true)
    fi
    write_version "NVIDIA_FABRIC_MANAGER" "${NFM_VERSION}"

    # IMEX: only ships on GB200. Best-effort — empty result is expected
    # everywhere else.
    IMEX_VERSION=""
    if command -v dpkg-query &>/dev/null; then
        IMEX_VERSION=$(dpkg-query -W -f='${Version}' nvidia-imex-* 2>/dev/null | head -1 | sed 's/-.*//' || true)
    fi
    write_version "IMEX" "${IMEX_VERSION}" best-effort
    
    # DCGM
    # 'datacenter-gpu-manager-4-core' is CUDA-version-agnostic and is
    # always installed by install_dcgm.sh alongside cuda<N> sub-packages
    # (which vary by SKU compute capability and aren't queried here). Keep
    # the full version (epoch '1:', Debian '-<rev>' suffix) for round-trip
    # (e.g. '1:4.5.3-1'). Query the single package by exact name — a
    # multi-glob dpkg-query silently returned empty for held packages
    # under set -euo pipefail.
    echo "[DCGM]"
    DCGM_VERSION=""
    if command -v dpkg-query &>/dev/null; then
        DCGM_VERSION=$(dpkg-query -W -f='${Version}\n' datacenter-gpu-manager-4-core 2>/dev/null || true)
    fi
    if [[ -z "${DCGM_VERSION}" ]] && command -v dpkg-query &>/dev/null; then
        # Legacy DCGM 3.x packaging used a single unversioned name.
        DCGM_VERSION=$(dpkg-query -W -f='${Version}\n' datacenter-gpu-manager 2>/dev/null || true)
    fi
    if [[ -z "${DCGM_VERSION}" ]] && command -v rpm &>/dev/null; then
        DCGM_VERSION=$(rpm -qa 'datacenter-gpu-manager-4-core' 'datacenter-gpu-manager*' --qf '%{VERSION}-%{RELEASE}\n' 2>/dev/null \
            | sort -V | tail -1 || true)
    fi
    if [[ -z "${DCGM_VERSION}" ]] && command -v dcgmi &>/dev/null; then
        DCGM_VERSION=$(dcgmi --version 2>/dev/null | awk '{print $3}' | head -1 || true)
    fi
    write_version "DCGM" "${DCGM_VERSION}"

    # GDRCopy
    # install_gdrcopy.sh writes the full version (e.g. '2.5.2-1'), but
    # dpkg's Version field only has the upstream '2.5.2' (the '-1' lives
    # in the .deb filename), so dpkg-query would downgrade the manifest.
    # GDRCopy is pinned on every target distro (apt-mark hold on Ubuntu,
    # dnf.conf exclude on RHEL, no auto-upgrade on AzureLinux), so it
    # can't drift here. Best-effort soft-preserve keeps the precise
    # install-time value (with '-<rev>' suffix) intact.
    echo "[GDRCopy]"
    GDRCOPY_VERSION=""
    write_version "GDRCOPY" "${GDRCOPY_VERSION}" best-effort

    # Docker / Moby Engine
    echo "[Container Runtime]"
    DOCKER_VERSION=""
    if command -v docker &>/dev/null; then
        DOCKER_VERSION=$(docker --version 2>/dev/null | awk '{print $3}' | sed 's/,//' || true)
    fi
    write_version "DOCKER" "${DOCKER_VERSION}"
    
    MOBY_VERSION=""
    # Keep full Debian/RPM version (e.g. '29.4.3-ubuntu24.04u1') to round-trip
    # with install_docker.sh's `apt list --installed` output.
    if command -v dpkg-query &>/dev/null; then
        MOBY_VERSION=$(dpkg-query -W -f='${Version}' moby-engine 2>/dev/null || true)
    fi
    if [[ -z "${MOBY_VERSION}" ]] && command -v rpm &>/dev/null; then
        MOBY_VERSION=$(rpm -q --qf '%{VERSION}-%{RELEASE}' moby-engine 2>/dev/null || true)
        [[ "${MOBY_VERSION}" == *"not installed"* ]] && MOBY_VERSION=""
    fi
    write_version "MOBY_ENGINE" "${MOBY_VERSION}"
    
    # NVIDIA Container Toolkit
    # `nvidia-container-toolkit --version` prints two lines (version + commit).
    # head -1 first so awk doesn't embed a newline into the JSON manifest.
    NCTK_VERSION=""
    if command -v nvidia-container-toolkit &>/dev/null; then
        NCTK_VERSION=$(nvidia-container-toolkit --version 2>/dev/null | head -1 | awk '{print $NF}' || true)
    fi
    write_version "NVIDIA_CONTAINER_TOOLKIT" "${NCTK_VERSION}"
    
    # NVBandwidth
    # Binary lives at /opt/nvidia/nvbandwidth/ (not on PATH); `--version`
    # initializes CUDA and fails on non-GPU SKUs, and there's no on-disk
    # version metadata. Best-effort: keep install-time entry on general SKUs.
    echo "[NVBandwidth]"
    NVBANDWIDTH_VERSION=""
    if [ -x /opt/nvidia/nvbandwidth/nvbandwidth ]; then
        # Only succeeds when a GPU is present; harmless when it doesn't.
        NVBANDWIDTH_VERSION=$(/opt/nvidia/nvbandwidth/nvbandwidth --version 2>/dev/null | head -1 | awk '{print $NF}' || true)
    fi
    write_version "NVBANDWIDTH" "${NVBANDWIDTH_VERSION}" best-effort

    # NVSHMEM: installed as libnvshmem3-cuda-<MAJOR> (apt/tdnf); no /opt path.
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

    # NVLOOM: no on-disk version signal and the binary needs GPU/MPI.
    # Best-effort soft-preserve.
    echo "[NVLOOM]"
    write_version "NVLOOM" "" best-effort
fi

# ---- AMD Components ----
if [[ "${GPU_PLATFORM}" == "AMD" ]]; then
    echo "[AMD GPU Stack]"

    # ROCm
    # install_rocm.sh writes bare MAJOR.MINOR.PATCH (e.g. "6.4.4"), but
    # /opt/rocm/.info/version carries an extra "-<build>" suffix from AMD's
    # packaging (e.g. "6.4.4-129"). Strip it to round-trip. `rocminfo`'s
    # Runtime Version already lacks the suffix.
    ROCM_VERSION=""
    if [ -f /opt/rocm/.info/version ]; then
        ROCM_VERSION=$(cat /opt/rocm/.info/version 2>/dev/null | sed -E 's/-[0-9]+$//' || true)
    elif command -v rocminfo &>/dev/null; then
        ROCM_VERSION=$(rocminfo 2>/dev/null | grep "Runtime Version" | awk '{print $NF}' || true)
    fi
    write_version "ROCM" "${ROCM_VERSION}"

    # RCCL
    # install_rccl.sh builds from source into the versionless prefix
    # /opt/rccl/ — no version on disk and not apt/dnf-managed, so it can't
    # drift. Best-effort soft-preserve keeps the install-time value.
    # (A previous glob-based detector accidentally picked up /opt/rccl-tests/
    # and produced the literal string "tests".)
    RCCL_VERSION=""
    write_version "RCCL" "${RCCL_VERSION}" best-effort
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
# install_intel_libs.sh writes the precise version (e.g. "2025.3.1.11"),
# but oneAPI's installer truncates the on-disk dir to major.minor
# (/opt/intel/oneapi/mkl/<major.minor>/). Same story as IMPI: /opt/intel
# isn't apt/dnf-managed, so it can't drift here. Best-effort soft-preserve.
echo "[Intel Libraries]"
INTEL_MKL_VERSION=""
write_version "INTEL_ONE_MKL" "${INTEL_MKL_VERSION}" best-effort

# ---- Lustre ----
# Prefer package-manager metadata to round-trip with install_lustre_client.sh:
#   Ubuntu source build: dpkg ${Version} of lustre-client-utils
#   Ubuntu repo:         amlfs-lustre-client-* ${Version}
#   RHEL:                amlfs-lustre-client-* / lustre-client*
# `lfs --version` only returns the build's internal version (no Debian
# revision); last-resort fallback only.
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
# install_dynolog_drl.sh builds from a git tag into /usr/local/bin with no
# package and no version sidecar. CLI --version formats aren't stable.
# Best-effort: install-time entry is source of truth; /usr/local/bin can't
# drift via apt.
echo "[Dynolog]"
DYNOLOG_VERSION=""
if command -v dynolog &>/dev/null; then
    if command -v dpkg-query &>/dev/null; then
        DYNOLOG_VERSION=$(dpkg-query -W -f='${Version}' dynolog 2>/dev/null | sed 's/-.*//' || true)
    fi
    if [[ -z "${DYNOLOG_VERSION}" ]] && command -v rpm &>/dev/null; then
        DYNOLOG_VERSION=$(rpm -q --qf '%{VERSION}' dynolog 2>/dev/null || true)
        [[ "${DYNOLOG_VERSION}" == *"not installed"* ]] && DYNOLOG_VERSION=""
    fi
fi
write_version "dynolog" "${DYNOLOG_VERSION}" best-effort

DRL_VERSION=""
if command -v dyno_relay_logger &>/dev/null; then
    DRL_VERSION=$(dyno_relay_logger --version 2>/dev/null | head -1 | awk '{print $NF}' || true)
fi
write_version "dyno_relay_logger" "${DRL_VERSION}" best-effort

# ---- Monitoring Tools (Moneo) ----
# install_monitoring_tools.sh extracts Moneo to /opt/azurehpc/tools/Moneo/
# without a version sidecar. Best-effort soft-preserve.
echo "[Monitoring]"
MONEO_VERSION=""
if [ -d /opt/azurehpc/tools/Moneo ]; then
    if [ -f /opt/azurehpc/tools/Moneo/version.txt ]; then
        MONEO_VERSION=$(cat /opt/azurehpc/tools/Moneo/version.txt 2>/dev/null || true)
    fi
fi
write_version "MONEO" "${MONEO_VERSION}" best-effort

# ---- Azure Health Checks ----
# install_health_checks.sh clones to /opt/azurehpc/test/azurehpc-health-checks/
# without a version sidecar. Best-effort soft-preserve.
echo "[Health Checks]"
AZHC_VERSION=""
if [ -d /opt/azurehpc/test/azurehpc-health-checks ]; then
    if [ -f /opt/azurehpc/test/azurehpc-health-checks/version.txt ]; then
        AZHC_VERSION=$(cat /opt/azurehpc/test/azurehpc-health-checks/version.txt 2>/dev/null || true)
    fi
fi
write_version "AZ_HEALTH_CHECKS" "${AZHC_VERSION}" best-effort

# ---- WAAgent ----
# On Alma9/Rocky9/RHEL9, install_waagent.sh installs WALinuxAgent via
# `python3.12 setup.py install` (system python3 9 is too old) and rewrites
# the systemd unit's ExecStart= line to point at python3.12. The rpm-shipped
# /usr/sbin/waagent shebang still says #!/usr/bin/python3, which resolves
# to the system python and reports the OLDER rpm-managed azurelinuxagent.
#
# Read the interpreter back out of the ExecStart= line instead of hard-coding
# python3.12 — robust to future Alma versions.
echo "[WAAgent]"
WAAGENT_VERSION=""
WAAGENT_EXT_VERSION=""

# Find the ExecStart= interpreter the unit was configured with. Unit may
# live in /usr/lib (vendor) or /etc (override); Ubuntu uses
# walinuxagent.service, others use waagent.service. ExecStart= format is
# `<interpreter> -u /usr/sbin/waagent -daemon` — grab the first token.
WAAGENT_PY=""
for svc in \
    /usr/lib/systemd/system/waagent.service \
    /usr/lib/systemd/system/walinuxagent.service \
    /etc/systemd/system/waagent.service \
    /etc/systemd/system/walinuxagent.service; do
    [ -f "${svc}" ] || continue
    candidate=$(awk -F'=' '/^ExecStart=/{print $2; exit}' "${svc}" 2>/dev/null \
        | awk '{print $1}')
    if [[ -n "${candidate}" && -x "${candidate}" ]]; then
        WAAGENT_PY="${candidate}"
        break
    fi
done

WAAGENT_OUT=""
if [[ -n "${WAAGENT_PY}" && -f /usr/sbin/waagent ]]; then
    WAAGENT_OUT=$("${WAAGENT_PY}" -u /usr/sbin/waagent --version 2>/dev/null || true)
fi
# Fallback: distros where the unit wasn't rewritten (Ubuntu, AzureLinux,
# RHEL/Alma 8) — shebang-resolved interpreter is correct on these.
if [[ -z "${WAAGENT_OUT}" ]] && command -v waagent &>/dev/null; then
    WAAGENT_OUT=$(waagent --version 2>/dev/null || true)
fi

if [[ -n "${WAAGENT_OUT}" ]]; then
    WAAGENT_VERSION=$(echo "${WAAGENT_OUT}" | head -n 1 | awk -F' ' '{print $1}' | awk -F- '{print $2}' || true)
    WAAGENT_EXT_VERSION=$(echo "${WAAGENT_OUT}" | sed '3q;d' | awk -F' ' '{print $4}' || true)
fi
write_version "WAAGENT" "${WAAGENT_VERSION}"
write_version "WAAGENT_EXTENSIONS" "${WAAGENT_EXT_VERSION}"

echo ""
if [[ "${REQUIRED_MISSING}" -gt 0 ]]; then
    echo "WARNING: ${REQUIRED_MISSING} REQUIRED detector(s) returned empty."
    echo "         Inherited manifest entries may be STALE if apt upgrade"
    echo "         changed the underlying packages. Audit the [WARN] lines"
    echo "         above and fix detectors in refresh_component_versions.sh."
fi
echo "=== component_versions.txt refresh complete ==="
echo "Output: ${COMPONENT_VERSIONS_FILE}"
echo ""
echo "Contents:"
cat "${COMPONENT_VERSIONS_FILE}"

if [[ "${REQUIRED_MISSING}" -gt 0 && "${STRICT}" == "1" ]]; then
    echo ""
    echo "STRICT=1: failing build because ${REQUIRED_MISSING} REQUIRED detector(s) returned empty."
    exit 1
fi
