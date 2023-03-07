#!/bin/bash
set -ex

# Parameter
# Ubuntu Version
VERSION=$1

# Install nvidia fabric manager
case ${VERSION} in
    1804) NVIDIA_FABRIC_MANAGER_VERSION="520_520.61.05-1"; 
        CHECKSUM="8beeb76ade836327298337b4f65eb3906498cebe71ab35bca5bb1a638c1bfd0a";
        VERSION_PREFIX="520";; 
    2004) NVIDIA_FABRIC_MANAGER_VERSION="525_525.85.12-1"; 
        CHECKSUM="77e2f8768e4901114c35582b530b10fe6bd3b924862a929f96fc83aee078b12c";
        VERSION_PREFIX="525";;
    2204) NVIDIA_FABRIC_MANAGER_VERSION="525_525.85.12-1"; 
        CHECKSUM="77e2f8768e4901114c35582b530b10fe6bd3b924862a929f96fc83aee078b12c";
        VERSION_PREFIX="525";;
    *) ;;
esac

NVIDIA_FABRIC_MNGR_URL=http://developer.download.nvidia.com/compute/cuda/repos/ubuntu${VERSION}/x86_64/nvidia-fabricmanager-${NVIDIA_FABRIC_MANAGER_VERSION}_amd64.deb
$COMMON_DIR/download_and_verify.sh $NVIDIA_FABRIC_MNGR_URL ${CHECKSUM}
apt install -y ./nvidia-fabricmanager-${NVIDIA_FABRIC_MANAGER_VERSION}_amd64.deb
apt-mark hold nvidia-fabricmanager-${VERSION_PREFIX}
$COMMON_DIR/write_component_version.sh "NVIDIA_FABRIC_MANAGER" ${NVIDIA_FABRIC_MANAGER_VERSION}
