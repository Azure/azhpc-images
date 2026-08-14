#!/bin/bash
set -euo pipefail

# =============================================================================
# Refresh Component Versions
# =============================================================================
# Refreshes /opt/azurehpc/component_versions.txt for components whose versions
# can change during the prerequisite apt/dnf transaction.
#
# Used during "in-place refresh" builds: an existing HPC image is the base
# and only `apt update` / `apt upgrade` runs. install_*.sh scripts do NOT
# re-run, so package-managed entries can drift. Pinned and source-installed
# entries remain unchanged from their install-time values.
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

mkdir -p /opt/azurehpc

# Install scripts remain the source of truth for pinned and source-installed
# components. Their install-time versions are often more precise than values
# recoverable from a versionless prefix or CLI after installation.
if [ ! -f "${COMPONENT_VERSIONS_FILE}" ]; then
    echo '{}' > "${COMPONENT_VERSIONS_FILE}"
fi

# Write a detected version, preserving the existing entry if detection fails.
write_version() {
    local component="$1"
    local version="$2"
    if [[ -n "${version}" && "${version}" != "null" ]]; then
        write_component_version "${component}" "${version}"
        echo "  [OK] ${component} = ${version}"
        return
    fi
    echo "  [WARN] ${component} detector returned empty; keeping existing entry, if any"
}

echo "=== Refreshing component_versions.txt ==="
echo "GPU Platform: ${GPU_PLATFORM}"
echo ""

# ---- Kernel ----
echo "[Kernel]"
KERNEL_VERSION=$(uname -r)
write_version "KERNEL" "${KERNEL_VERSION}"

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

    # IMEX only ships on GB200; absence is expected everywhere else.
    IMEX_VERSION=""
    if command -v dpkg-query &>/dev/null; then
        IMEX_VERSION=$(dpkg-query -W -f='${Version}' nvidia-imex-* 2>/dev/null | head -1 | sed 's/-.*//' || true)
    fi
    if [[ -n "${IMEX_VERSION}" ]]; then
        write_version "IMEX" "${IMEX_VERSION}"
    fi
    
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
    if [[ -n "${NVSHMEM_VERSION}" ]]; then
        write_version "NVSHMEM" "${NVSHMEM_VERSION}"
    fi
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

fi

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
echo "=== component_versions.txt refresh complete ==="
echo "Output: ${COMPONENT_VERSIONS_FILE}"
echo ""
echo "Contents:"
cat "${COMPONENT_VERSIONS_FILE}"
