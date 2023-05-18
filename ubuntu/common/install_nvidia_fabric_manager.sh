#!/bin/bash
set -ex

# Parameter
# Ubuntu Version
VERSION=$1

# Install nvidia fabric manager
case ${VERSION} in
    1804) NVIDIA_FABRIC_MANAGER_VERSION="525_525.105.17-1"; 
        CHECKSUM="b487db5923194ba9f4d7c34891f4f8513a3f633a22a0c9f51fba3ef971681977";
        VERSION_PREFIX="525";; 
    2004) NVIDIA_FABRIC_MANAGER_VERSION="525_525.105.17-1"; 
        CHECKSUM="b487db5923194ba9f4d7c34891f4f8513a3f633a22a0c9f51fba3ef971681977";
        VERSION_PREFIX="525";;
    2204) NVIDIA_FABRIC_MANAGER_VERSION="525_525.105.17-1"; 
        CHECKSUM="b487db5923194ba9f4d7c34891f4f8513a3f633a22a0c9f51fba3ef971681977";
        VERSION_PREFIX="525";;
    *) ;;
esac

NVIDIA_FABRIC_MNGR_URL=http://developer.download.nvidia.com/compute/cuda/repos/ubuntu${VERSION}/x86_64/nvidia-fabricmanager-${NVIDIA_FABRIC_MANAGER_VERSION}_amd64.deb
$COMMON_DIR/download_and_verify.sh $NVIDIA_FABRIC_MNGR_URL ${CHECKSUM}
apt install -y ./nvidia-fabricmanager-${NVIDIA_FABRIC_MANAGER_VERSION}_amd64.deb
apt-mark hold nvidia-fabricmanager-${VERSION_PREFIX}
$COMMON_DIR/write_component_version.sh "NVIDIA_FABRIC_MANAGER" ${NVIDIA_FABRIC_MANAGER_VERSION}
