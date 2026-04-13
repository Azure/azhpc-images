#!/bin/bash
set -ex

if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Error: Missing arguments. Please provide both GPU type (NVIDIA/AMD) and SKU."
    exit 1
fi

export GPU=$1
export SKU=$2

if [[ "$GPU" != "NVIDIA" ]]; then
    echo "Error: NixOS currently only supports NVIDIA GPU platform."
    exit 1
fi

export TOP_DIR="$(dirname "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)")"
export COMPONENT_DIR=$TOP_DIR/components
export ARCHITECTURE=$(uname -m)

echo "NixOS 25.11 HPC component installation"
echo "GPU Platform: $GPU"
echo "GPU SKU: $SKU"
echo "Architecture: $ARCHITECTURE"

./install_utils.sh

if [ -f "$TOP_DIR/versions.json" ]; then
    echo "Loading component versions from versions.json"
    export COMPONENT_VERSIONS=$(cat $TOP_DIR/versions.json)
fi

echo "Installing DOCA OFED"
$COMPONENT_DIR/install_doca.sh || echo "WARNING: DOCA install failed (may need FHS compat layer)"

echo "Installing MPI libraries"
$COMPONENT_DIR/install_mpis.sh || echo "WARNING: MPI install failed (may need FHS compat layer)"

if [ "$GPU" = "NVIDIA" ]; then
    if [ "$SKU" = "GB200" ] || [ "$SKU" = "GB300" ]; then
        echo "Installing NVIDIA GPU driver for $SKU"
        ./install_nvidiagpudriver_gb200.sh || echo "WARNING: NVIDIA driver install requires matching kernel headers"

        echo "Installing NVSHMEM"
        $COMPONENT_DIR/install_nvshmem.sh || true

        echo "Installing NVLOOM"
        $COMPONENT_DIR/install_nvloom.sh || true

        echo "Installing NVBandwidth tool"
        $COMPONENT_DIR/install_nvbandwidth_tool.sh || true
    else
        echo "Installing NVIDIA GPU driver"
        $COMPONENT_DIR/install_nvidiagpudriver.sh || echo "WARNING: NVIDIA driver install requires matching kernel headers"
    fi

    echo "Installing NCCL"
    $COMPONENT_DIR/install_nccl.sh || true

    echo "Installing DCGM"
    $COMPONENT_DIR/install_dcgm.sh || true
fi

echo "Recording component versions"
VERSIONS_FILE=/opt/azurehpc/component_versions.txt
mkdir -p /opt/azurehpc
nixos_version=$(nixos-version 2>/dev/null || echo "unknown")
kernel_version=$(uname -r)
echo "{\"NixOS\": \"${nixos_version}\", \"Kernel\": \"${kernel_version}\", \"GPU\": \"${GPU}\", \"SKU\": \"${SKU}\"}" | jq . > $VERSIONS_FILE

rm -rf *.tgz *.bz2 *.tbz *.tar.gz *.run *.deb *_offline.sh
rm -rf /tmp/MLNX_OFED_LINUX* /tmp/*conf*

echo "NixOS HPC component installation complete"
