#!/bin/bash
set -ex

source ${UTILS_DIR}/utilities.sh

case "${DISTRIBUTION}" in
    ubuntu22.04|ubuntu24.04|ubuntu26.04) ;;
    *)
        echo "ERROR: CUDA APT repository setup is only supported on Ubuntu." >&2
        exit 1
        ;;
esac

case "${ARCHITECTURE}" in
    x86_64) CUDA_ARCHITECTURE=x86_64 ;;
    aarch64) CUDA_ARCHITECTURE=sbsa ;;
    *)
        echo "ERROR: Unsupported CUDA repository architecture: ${ARCHITECTURE}" >&2
        exit 1
        ;;
esac

cuda_metadata=$(get_component_config "cuda")
if ! CUDA_DRIVER_DISTRIBUTION=$(jq -er '.driver.distribution | strings | select(length > 0)' <<< "${cuda_metadata}"); then
    echo "ERROR: Missing CUDA repository distribution for ${DISTRIBUTION}/${ARCHITECTURE}." >&2
    exit 1
fi

CUDA_KEYRING_DEB=cuda-keyring_1.1-1_all.deb
curl -fsSL --retry 3 -o "${CUDA_KEYRING_DEB}" \
    "https://developer.download.nvidia.com/compute/cuda/repos/${CUDA_DRIVER_DISTRIBUTION}/${CUDA_ARCHITECTURE}/${CUDA_KEYRING_DEB}"
apt-get install -y "./${CUDA_KEYRING_DEB}"
rm -f "${CUDA_KEYRING_DEB}"

cat > /etc/apt/preferences.d/cuda-dkms-pin <<'EOF'
# NVIDIA's prebuilt DKMS is more up-to-date than Ubuntu's and DOCA's copies.
# Prefer its latest version for /etc/dkms patch overlays and rebuild fixes.
Package: dkms
Pin: release l=NVIDIA CUDA
Pin-Priority: 700
EOF

if [[ "${GPU}" == "AMD" ]]; then
    cat >> /etc/apt/preferences.d/cuda-dkms-pin <<'EOF'

# AMD images use only DKMS from this repository. Keep its exception above
# this per-package regex, which overrides cuda-keyring's generic priority 600.
# A generic "Package: *" negative pin would not override that priority.
Package: /.+/
Pin: release l=NVIDIA CUDA
Pin-Priority: -1
EOF
fi

apt-get update
apt-get install -y dkms
