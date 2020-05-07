#!/bin/bash
set -ex

CUDA_PIN_DOWNLOAD_URL=https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64/cuda-ubuntu1804.pin
$COMMON_DIR/download_and_verify.sh $CUDA_PIN_DOWNLOAD_URL "d10f04a7cda0bc8782c604083576532533cb7317ba0bb31857535c68ef0c9c76"
mv cuda-ubuntu1804.pin /etc/apt/preferences.d/cuda-repository-pin-600

PUBKEY_URL=/var/cuda-repo-10-2-local-10.2.89-440.33.01/7fa2af80.pub
CUDA_REPO_PKG=cuda-repo-ubuntu1804-10-2-local-10.2.89-440.33.01_1.0-1_amd64.deb

CUDA_REPO_DOWNLOAD_URL=http://developer.download.nvidia.com/compute/cuda/10.2/Prod/local_installers/cuda-repo-ubuntu1804-10-2-local-10.2.89-440.33.01_1.0-1_amd64.deb
$COMMON_DIR/download_and_verify.sh $CUDA_REPO_DOWNLOAD_URL "a9a5ab0324291b25170245ad39817684487f9bceda1848f05be1b53acd55fafc"
dpkg -i ${CUDA_REPO_PKG}
apt-key add ${PUBKEY_URL}
apt-get update
apt-get install --no-install-recommends -y cuda-drivers
apt-get -y install cuda
