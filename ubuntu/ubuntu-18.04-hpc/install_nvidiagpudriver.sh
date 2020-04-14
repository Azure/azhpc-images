#!/bin/bash
set -ex

wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64/cuda-ubuntu1804.pin
mv cuda-ubuntu1804.pin /etc/apt/preferences.d/cuda-repository-pin-600

PUBKEY_URL=/var/cuda-repo-10-2-local-10.2.89-440.33.01/7fa2af80.pub
CUDA_REPO_PKG=cuda-repo-ubuntu1804-10-2-local-10.2.89-440.33.01_1.0-1_amd64.deb

wget http://developer.download.nvidia.com/compute/cuda/10.2/Prod/local_installers/cuda-repo-ubuntu1804-10-2-local-10.2.89-440.33.01_1.0-1_amd64.deb

dpkg -i ${CUDA_REPO_PKG}
apt-key add ${PUBKEY_URL}
apt-get update
apt-get install --no-install-recommends -y cuda-drivers
apt-get -y install cuda
