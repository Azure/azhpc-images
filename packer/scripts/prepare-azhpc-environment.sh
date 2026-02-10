#!/bin/bash
set -euo pipefail

# =============================================================================
# Prepare azhpc-images environment
# =============================================================================
# This script sets up the azhpc-images environment on the build VM.
# The repository is uploaded via Packer's file provisioner.

AZHPC_SUBMODULE_PATH="${AZHPC_SUBMODULE_PATH:-/tmp/azhpc-images}"
AZHPC_DIR="${AZHPC_DIR:-/opt/azhpc-images}"

echo "=========================================="
echo "Preparing azhpc-images Environment"
echo "Source Path: ${AZHPC_SUBMODULE_PATH}"
echo "Target Directory: ${AZHPC_DIR}"
echo "=========================================="

# Check if repository was uploaded
if [[ ! -d "${AZHPC_SUBMODULE_PATH}" ]]; then
    echo "ERROR: azhpc-images not found at ${AZHPC_SUBMODULE_PATH}"
    echo "Make sure the repository is uploaded by Packer"
    exit 1
fi

# Move to target location
if [[ -d "${AZHPC_DIR}" ]]; then
    echo "Removing existing directory at ${AZHPC_DIR}..."
    rm -rf "${AZHPC_DIR}"
fi

echo "Moving azhpc-images to ${AZHPC_DIR}..."
mv "${AZHPC_SUBMODULE_PATH}" "${AZHPC_DIR}"
cd "${AZHPC_DIR}"

# Fix permissions - Packer file provisioner doesn't preserve execute bits
echo "Fixing script permissions..."
find "${AZHPC_DIR}" -name "*.sh" -exec chmod +x {} \;
chmod -R +x "${AZHPC_DIR}/components" 2>/dev/null || true
chmod -R +x "${AZHPC_DIR}/tests" 2>/dev/null || true
chmod -R +x "${AZHPC_DIR}/utils" 2>/dev/null || true
chmod -R +x "${AZHPC_DIR}/distros" 2>/dev/null || true

# Get commit information from environment variables (passed by Packer)
COMMIT_ID="${AZHPC_COMMIT:-unknown}"
if [[ "${COMMIT_ID}" != "unknown" && ${#COMMIT_ID} -ge 7 ]]; then
    COMMIT_SHORT="${COMMIT_ID:0:7}"
else
    COMMIT_SHORT="${COMMIT_ID}"
fi
COMMIT_DATE=$(date +%Y-%m-%d)

REPO_URL="${AZHPC_REPO_URL:-unknown}"
REPO_BRANCH="${AZHPC_BRANCH:-unknown}"

echo "azhpc-images setup:"
echo "  Repository: ${REPO_URL}"
echo "  Branch: ${REPO_BRANCH}"
echo "  Commit: ${COMMIT_SHORT} (${COMMIT_ID})"
echo "  Date: ${COMMIT_DATE}"

# Set up environment variables for azhpc-images scripts
export TOP_DIR="${AZHPC_DIR}"
export COMPONENT_DIR="${TOP_DIR}/components"
export TEST_DIR="${TOP_DIR}/tests"
export UTILS_DIR="${TOP_DIR}/utils"
export DISTRIBUTION=$(. /etc/os-release; echo $ID$VERSION_ID)

# Set non-interactive mode for package installations
export DEBIAN_FRONTEND=noninteractive
export AZNFS_NONINTERACTIVE_INSTALL=1

# Ensure apt progress bars are disabled (for cleaner Packer output)
if [[ -d /etc/apt/apt.conf.d ]]; then
    cat > /etc/apt/apt.conf.d/99-disable-progress << 'APTEOF'
Dpkg::Progress-Fancy "0";
Dpkg::Progress "0";
APT::Color "0";
APT::Acquire::Progress "0";
Acquire::Progress::Fancy "0";
Acquire::Progress "0";
Dpkg::Use-Pty "0";
quiet "2";
APTEOF
fi

# Determine architecture
if [[ $(uname -m) == "x86_64" ]]; then
    export ARCHITECTURE_DISTRO="amd64"
    export ARCHITECTURE="x86_64"
elif [[ $(uname -m) == "aarch64" ]]; then
    export ARCHITECTURE_DISTRO="arm64"
    export ARCHITECTURE="aarch64"
fi

echo "Environment variables set:"
echo "  DISTRIBUTION: ${DISTRIBUTION}"
echo "  ARCHITECTURE: ${ARCHITECTURE}"
echo "  TOP_DIR: ${TOP_DIR}"
echo "  COMPONENT_DIR: ${COMPONENT_DIR}"
echo "  AKS_HOST_IMAGE: ${AKS_HOST_IMAGE:-false}"

# Set SKU based on GPU_SKU (required)
export SKU=$(echo "${GPU_SKU}" | tr '[:lower:]' '[:upper:]')
echo "SKU set to: '${SKU}'"

# Source set_properties.sh to set up environment
echo "Sourcing set_properties.sh from azhpc-images..."
cd "${TOP_DIR}"
source "${UTILS_DIR}/set_properties.sh"
echo "Environment setup complete via set_properties.sh"

# Capture COMPONENT_VERSIONS
CAPTURED_COMPONENT_VERSIONS="${COMPONENT_VERSIONS:-}"

# Create marker directory with build information
mkdir -p /opt/packer
cat > /opt/packer/azhpc-build-info.txt <<EOF
AZHPC_IMAGES_REPO=${REPO_URL}
AZHPC_IMAGES_BRANCH=${REPO_BRANCH}
AZHPC_IMAGES_COMMIT=${COMMIT_ID}
AZHPC_IMAGES_COMMIT_SHORT=${COMMIT_SHORT}
AZHPC_IMAGES_COMMIT_DATE=${COMMIT_DATE}
BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
DISTRIBUTION=${DISTRIBUTION}
ARCHITECTURE=${ARCHITECTURE}
AKS_HOST_IMAGE=${AKS_HOST_IMAGE:-false}
EOF

# Create environment file for subsequent scripts
cat > /etc/profile.d/azhpc-env.sh <<EOF
# azhpc-images environment
export TOP_DIR=/opt/azhpc-images
export COMPONENT_DIR=\$TOP_DIR/components
export TEST_DIR=\$TOP_DIR/tests
export UTILS_DIR=\$TOP_DIR/utils
export DISTRIBUTION=\$(. /etc/os-release; echo \$ID\$VERSION_ID)
export ARCHITECTURE=\$(uname -m)
if [[ \$(uname -m) == "x86_64" ]]; then
    export ARCHITECTURE_DISTRO="amd64"
elif [[ \$(uname -m) == "aarch64" ]]; then
    export ARCHITECTURE_DISTRO="arm64"
fi
export MODULE_FILES_DIRECTORY=/usr/share/modules/modulefiles
export COMPONENT_VERSIONS='${CAPTURED_COMPONENT_VERSIONS}'
export DEBIAN_FRONTEND=noninteractive
export AKS_HOST_IMAGE=${AKS_HOST_IMAGE:-false}
EOF

chmod +x /etc/profile.d/azhpc-env.sh

echo "=========================================="
echo "azhpc-images environment prepared successfully"
echo "=========================================="
