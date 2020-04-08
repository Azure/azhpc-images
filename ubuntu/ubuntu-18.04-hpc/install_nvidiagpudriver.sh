#!/bin/bash
set -ex

# Change versions (Ubuntu, GPU driver) here if needed
# See https://github.com/Azure/azhpc-extensions/blob/master/NvidiaGPU/resources.json
DRIVER_URL=https://go.microsoft.com/fwlink/?linkid=874271
CUDA_REPO_PKG=cuda-repo-ubuntu_amd64.deb
PUBKEY_URL=http://download.microsoft.com/download/F/F/A/FFAC979D-AD9C-4684-A6CE-C92BB9372A3B/7fa2af80.pub

sudo wget --retry-connrefused --tries=3 --waitretry=5 $DRIVER_URL -O $CUDA_REPO_PKG -nv # Download tarball
sudo dpkg -i $CUDA_REPO_PKG
sudo apt-key adv --fetch-keys $PUBKEY_URL 
sudo apt-get install --no-install-recommends -y cuda-drivers
sudo apt-get install -y cuda
