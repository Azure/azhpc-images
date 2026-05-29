#!/bin/bash
set -euo pipefail

# =============================================================================
# Refresh Component Versions
# =============================================================================
# Regenerates /opt/azurehpc/component_versions.txt by detecting the actual
# installed versions of all HPC components on the running system.
#
# This script is used during "in-place refresh" builds where an existing HPC
# image is used as a base and only `apt update` / `apt upgrade` is run to
# pick up newer general packages, kernels, and kmods. None of the
# components/install_*.sh scripts are re-executed in this mode, so the
# manifest written at original build time can drift from what's actually
# installed. This script queries the system (package managers, binaries,
# modulefiles, etc.) to rebuild an accurate manifest from ground truth.
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

# STRICT=1 fails the script at the end if any REQUIRED detector returned
# empty. Default is warn-only so existing CI keeps passing while operators
# investigate. The counter is incremented by write_version when a
# 'required' detector misses; see the trailing summary block.
STRICT="${STRICT:-0}"
REQUIRED_MISSING=0

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

# Helper: write a component's version, classified by tier.
#
# Tiers:
#   required    (default) — The detector MUST succeed on the build host:
#                 the component is either apt/dnf-managed (so apt upgrade
#                 can mutate it between builds and the manifest must
#                 reflect the new version) or has a stable, hardware-free
#                 on-disk version signal. An empty result is treated as a
#                 regression: log [WARN], increment REQUIRED_MISSING, and
#                 (when STRICT=1) fail the script at the end. Soft-preserve
#                 still happens — we don't drop the prior entry — but the
#                 build is no longer silent about it.
#   best-effort — The detector cannot reliably succeed on the build host.
#                 Either the component is hardware-gated (e.g. NVBANDWIDTH
#                 needs a GPU to self-report, NVLOOM has no on-disk
#                 metadata at all, IMEX only ships on GB200) or the
#                 install layout deliberately encodes no version (e.g.
#                 mpifileutils, Moneo, dynolog). For these, the prior
#                 manifest entry written by install_*.sh is the source of
#                 truth; an empty refresh result is expected and silently
#                 retains it.
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

# DOCA version: check dpkg or rpm.
# install_doca.sh installs the 'doca-host' .deb on Ubuntu (which then
# pulls in doca-ofed via apt), and either 'doca-host' or 'doca-extra' /
# 'doca-ofed' on RPM-based distros. The legacy 'doca-runtime' metapackage
# referenced by the previous detector no longer exists in DOCA 3.x.
# install_doca.sh writes only the leading 'X.Y.Z' from versions.json, so
# strip the trailing '-<build>-<ofed>-<distro>' suffix to round-trip.
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
# install_pmix.sh installs the 'pmix' apt package (Ubuntu) / 'pmix' dnf
# package (RHEL/AzureLinux) and writes the package version (e.g.
# '4.2.9-1') to the manifest. Prefer package-manager metadata so the
# refreshed value round-trips with what install_pmix.sh wrote; pmix_info
# and pkg-config are unreliable here (pmix_info lives in HPC-X's tree and
# isn't on PATH; pkg-config needs libpmix-dev which isn't installed).
echo "[PMIx]"
PMIX_VERSION=""
if command -v dpkg-query &>/dev/null; then
    PMIX_VERSION=$(dpkg-query -W -f='${Version}\n' pmix 2>/dev/null || true)
fi
if [[ -z "${PMIX_VERSION}" ]] && command -v rpm &>/dev/null; then
    PMIX_VERSION=$(rpm -q --qf '%{VERSION}-%{RELEASE}\n' pmix 2>/dev/null || true)
    [[ "${PMIX_VERSION}" == *"not installed"* ]] && PMIX_VERSION=""
fi
# Last-resort fallbacks (rarely needed; the apt/dnf path above is the
# install_pmix.sh code path on every supported distro).
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
# install_mpis.sh writes the precise marketing version from versions.json
# (e.g. "2021.16.1"), but the Intel oneAPI offline installer creates the
# install directory at /opt/intel/oneapi/mpi/<major.minor>/ — the trailing
# ".<patch>" is lost on disk. Falling back to the directory basename would
# downgrade the manifest from "2021.16.1" to "2021.16" on every refresh.
#
# Intel oneAPI components live entirely under /opt/intel and are NOT
# managed by apt/dnf, so they cannot be mutated by the `apt upgrade` step
# that motivates this script. The entry written by install_mpis.sh on the
# base image therefore remains ground truth across in-place refreshes.
# Mark as best-effort and skip detection entirely so the soft-preserve
# path keeps the precise install-time value.
#
# (mpirun --version, the only on-system source we have, also reports just
# the major.minor — so there is no precise auto-detection path available.)
IMPI_VERSION=""
write_version "IMPI" "${IMPI_VERSION}" best-effort

# ---- mpiFileUtils ----
# install_mpifileutils.sh builds from a versioned tarball and installs into
# the versionless prefix /opt/mpifileutils/. No version is encoded in the
# install layout, the CLI tools (dbcast/dcp/...) don't reliably expose
# --version, and there is no pkg-config file shipped by upstream. The
# previous detector both (a) gated on `command -v dbcast`, which is never
# on PATH because /opt/mpifileutils/bin isn't, and (b) globbed for
# /opt/mpifileutils-*, which never matches the real install dir.
# Best-effort soft-preserve is correct: apt upgrade cannot mutate
# /opt/mpifileutils, so the entry written by install_mpifileutils.sh on
# the base image is still ground truth.
echo "[mpiFileUtils]"
write_version "MPIFILEUTILS" "" best-effort

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
    # install_nvidiagpudriver.sh writes the value parsed from
    #   `nvcc --version | grep release | awk '{print $6}' | cut -c2-`
    # which is the "V<X.Y.Z>" build/toolchain version (e.g. "13.0.88").
    # The CUDA Toolkit ships two distinct version strings in
    # /usr/local/cuda/version.json:
    #   .cuda.version   — marketing/release version (e.g. "13.0.3")
    #   .nvcc.version   — build/toolchain version (e.g. "13.0.88")
    # To round-trip with install_nvidiagpudriver.sh we MUST prefer the
    # nvcc/toolchain build number, not the marketing version.
    #
    # Order of preference (most precise + round-trips with install):
    #   1. /usr/local/cuda/version.json .nvcc.version — full build version,
    #      doesn't need nvcc on PATH or a working CUDA shell environment.
    #   2. nvcc --version "V<X.Y.Z>" token — same value, queried from the
    #      binary directly. /usr/local/cuda/bin/nvcc usually isn't on PATH
    #      for non-login shells, so call it by absolute path.
    #   3. /usr/local/cuda/version.json .cuda.version — marketing version,
    #      LESS precise than nvcc.version but still preferable to nothing.
    #      Older CUDA Toolkit releases (pre-13) may only ship this key.
    #   4. /usr/local/cuda/version.txt — legacy CUDA (<11) fallback.
    #   5. readlink -f /usr/local/cuda — follows the full alternatives chain
    #      (/usr/local/cuda -> /etc/alternatives/cuda -> /usr/local/cuda-X.Y)
    #      and uses the leaf directory name. Only carries major.minor.
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
        # Last-resort: marketing version (.cuda.version). Less precise than
        # .nvcc.version but at least we get major.minor.patch.
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

    # IMEX (only on GB200). Best-effort: nvidia-imex-* is not installed on
    # any other SKU; an empty result is expected and the prior manifest
    # entry (if any) is the source of truth.
    IMEX_VERSION=""
    if command -v dpkg-query &>/dev/null; then
        IMEX_VERSION=$(dpkg-query -W -f='${Version}' nvidia-imex-* 2>/dev/null | head -1 | sed 's/-.*//' || true)
    fi
    write_version "IMEX" "${IMEX_VERSION}" best-effort
    
    # DCGM
    # The 'datacenter-gpu-manager-4-core' package is CUDA-version-agnostic
    # and is always installed by install_dcgm.sh alongside one or more
    # cuda<N> sub-packages (the sub-packages vary by SKU's compute
    # capability, so we don't query them). Keep the full version string
    # (with epoch '1:' and Debian '-<rev>' suffix) so it round-trips with
    # install_dcgm.sh's write_component_version call (e.g. '1:4.5.3-1').
    #
    # The previous detector globbed three patterns in one dpkg-query call
    # (...-core ...-cuda* and the unversioned name); the multi-arg call
    # was returning empty under set -euo pipefail on Ubuntu 24.04 even
    # though `-core` was installed in 'hi' (hold + installed) state, so we
    # silently kept the previous manifest's version across apt upgrades.
    # Querying the single package directly is more robust.
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
    # install_gdrcopy.sh writes the full version string from versions.json
    # (e.g. '2.5.2-1'), but the deb's control-file Version field is just
    # the upstream-only '2.5.2' (the '-1' lives only in the .deb filename),
    # so a dpkg-query round-trip would silently downgrade the manifest on
    # every refresh.
    #
    # GDRCopy is pinned on every distro the refresh script targets:
    #   - Ubuntu (source build): all 4 .debs are `apt-mark hold`'d right
    #     after `dpkg -i`, so `apt upgrade` cannot mutate them.
    #   - RHEL family: install_gdrcopy.sh appends `gdrcopy*` to the
    #     `exclude=` line in /etc/dnf/dnf.conf, so `dnf update` skips them.
    #   - AzureLinux 3.0: install_gdrcopy.sh already reads the installed
    #     version back from `tdnf list installed`, so install and refresh
    #     trivially agree (and gdrcopy isn't auto-upgraded in practice).
    #
    # Since apt/dnf/tdnf upgrades cannot drift GDRCopy under this script,
    # the entry written by install_gdrcopy.sh on the base image remains
    # ground truth across in-place refreshes. Mark as best-effort and skip
    # detection so the soft-preserve path keeps the precise install-time
    # value (with the '-<rev>' suffix) intact.
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
        # Only succeeds when a GPU is present; harmless when it doesn't.
        NVBANDWIDTH_VERSION=$(/opt/nvidia/nvbandwidth/nvbandwidth --version 2>/dev/null | head -1 | awk '{print $NF}' || true)
    fi
    write_version "NVBANDWIDTH" "${NVBANDWIDTH_VERSION}" best-effort

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
    write_version "NVLOOM" "" best-effort
fi

# ---- AMD Components ----
if [[ "${GPU_PLATFORM}" == "AMD" ]]; then
    echo "[AMD GPU Stack]"

    # ROCm
    # install_rocm.sh writes the bare MAJOR.MINOR.PATCH from versions.json
    # (e.g. "6.4.4"), but ROCm's on-disk version file /opt/rocm/.info/version
    # carries an additional "-<build>" suffix appended by AMD's packaging
    # (e.g. "6.4.4-129"). Strip the trailing "-<digits>" so the refreshed
    # value round-trips with what install_rocm.sh recorded. `rocminfo`'s
    # "Runtime Version" output already lacks the suffix, so no strip needed
    # there.
    ROCM_VERSION=""
    if [ -f /opt/rocm/.info/version ]; then
        ROCM_VERSION=$(cat /opt/rocm/.info/version 2>/dev/null | sed -E 's/-[0-9]+$//' || true)
    elif command -v rocminfo &>/dev/null; then
        ROCM_VERSION=$(rocminfo 2>/dev/null | grep "Runtime Version" | awk '{print $NF}' || true)
    fi
    write_version "ROCM" "${ROCM_VERSION}"

    # RCCL
    # install_rccl.sh builds RCCL from source and installs it to the
    # VERSIONLESS prefix /opt/rccl/ (cmake -DCMAKE_INSTALL_PREFIX=/opt/rccl).
    # There is no /opt/rccl-<X.Y.Z>/ directory to read the version from.
    # The previous detector globbed /opt/rccl* and sort -V'd it; on AMD
    # images that also install the RCCL test suite under /opt/rccl-tests/,
    # `sort -V` ranks "rccl-tests" AFTER "rccl" (letters > digits), and the
    # subsequent `sed 's/^rccl-//'` then produced the literal string
    # "tests" as the manifest value.
    #
    # /opt/rccl/ is a from-source install and is NOT managed by apt/dnf, so
    # `apt upgrade` cannot mutate it. The entry written by install_rccl.sh
    # on the base image remains ground truth across in-place refreshes.
    # Mark as best-effort and skip detection so the soft-preserve path
    # keeps the precise install-time value intact.
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
# install_intel_libs.sh writes the precise marketing version from
# versions.json (e.g. "2025.3.1.11"), but the Intel oneAPI offline
# installer lands MKL at /opt/intel/oneapi/mkl/<major.minor>/ — the
# trailing ".<patch>.<build>" is lost on disk. Falling back to the
# directory basename would downgrade the manifest from "2025.3.1.11" to
# "2025.3" on every refresh.
#
# Same rationale as IMPI above: Intel oneAPI components live under
# /opt/intel and are NOT managed by apt/dnf, so they cannot be mutated by
# the `apt upgrade` step that motivates this script. The entry written by
# install_intel_libs.sh on the base image remains ground truth across
# in-place refreshes. Mark as best-effort and skip detection so the
# soft-preserve path keeps the install-time value intact.
echo "[Intel Libraries]"
INTEL_MKL_VERSION=""
write_version "INTEL_ONE_MKL" "${INTEL_MKL_VERSION}" best-effort

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
# install_dynolog_drl.sh builds both from a git tag and installs them to
# /usr/local/bin without a Debian package and without a sidecar version
# file. `dynolog --version` and `dyno_relay_logger --version` exist but
# the format isn't guaranteed across upstream versions. Treat as
# best-effort: the entry written by install_dynolog_drl.sh is the source
# of truth, and apt upgrade can't mutate the /usr/local/bin binaries.
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
# install_monitoring_tools.sh extracts the Moneo source tarball to
# /opt/azurehpc/tools/Moneo/ but does not drop a version.txt sidecar, so
# the on-disk install has no version signal. Best-effort soft-preserve
# of the entry written by install_monitoring_tools.sh.
echo "[Monitoring]"
MONEO_VERSION=""
if [ -d /opt/azurehpc/tools/Moneo ]; then
    if [ -f /opt/azurehpc/tools/Moneo/version.txt ]; then
        MONEO_VERSION=$(cat /opt/azurehpc/tools/Moneo/version.txt 2>/dev/null || true)
    fi
fi
write_version "MONEO" "${MONEO_VERSION}" best-effort

# ---- Azure Health Checks ----
# Same situation as Moneo: install_health_checks.sh clones the repo into
# /opt/azurehpc/test/azurehpc-health-checks/ but doesn't write a
# version.txt sidecar. Best-effort soft-preserve.
echo "[Health Checks]"
AZHC_VERSION=""
if [ -d /opt/azurehpc/test/azurehpc-health-checks ]; then
    if [ -f /opt/azurehpc/test/azurehpc-health-checks/version.txt ]; then
        AZHC_VERSION=$(cat /opt/azurehpc/test/azurehpc-health-checks/version.txt 2>/dev/null || true)
    fi
fi
write_version "AZ_HEALTH_CHECKS" "${AZHC_VERSION}" best-effort

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
if [[ "${REQUIRED_MISSING}" -gt 0 ]]; then
    echo "WARNING: ${REQUIRED_MISSING} REQUIRED detector(s) returned empty."
    echo "         The manifest entries for those components were inherited from"
    echo "         the prior build and may be STALE if apt upgrade changed the"
    echo "         underlying packages. Audit the [WARN] lines above and fix the"
    echo "         affected detector(s) in components/refresh_component_versions.sh."
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
