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

echo "NixOS 25.11 HPC component installation"
echo "GPU Platform: $GPU"
echo "GPU SKU: $SKU"

./install_utils.sh

echo "NixOS HPC component installation complete"
