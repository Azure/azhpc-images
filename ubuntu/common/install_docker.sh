#!/bin/bash
set -ex

# Install Moby Engine
VERSION="3.0.1"
$COMMON_DIR/write_component_version.sh "MOBY" $VERSION
TARBALL="moby-$VERSION.tar.gz"
MOBY_DOWNLOAD_URL=https://azhpcstor.blob.core.windows.net/azhpc-images-store/$TARBALL
$COMMON_DIR/download_and_verify.sh ${MOBY_DOWNLOAD_URL} "7c91437fe67a6f51042896256843a50ffde83bd72b5d24fec3c0602781ceffa9"
tar -xvzf ${TARBALL}
tar -xvzf moby/amd64/artifacts.tgz -C moby/amd64/
dpkg -i moby/amd64/bundles/debbuild/ubuntu-xenial/moby-engine_${VERSION}_amd64.deb

# Install Moby CLI
TARBALL="cli-$VERSION.tar.gz"
CLI_DOWNLOAD_URL=https://azhpcstor.blob.core.windows.net/azhpc-images-store/$TARBALL
$COMMON_DIR/download_and_verify.sh ${CLI_DOWNLOAD_URL} "6304942e8e99ddef30be63df33546e313b46128755e205af4e9fe12f50462ee6"
tar -xvzf cli-$VERSION.tar.gz
tar -xvzf cli/amd64/artifacts.tgz -C cli/amd64/
dpkg -i cli/amd64/bundles/debbuild/ubuntu-xenial/moby-cli_${VERSION}_amd64.deb

# Install NVIDIA Docker
# Reference: https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html
# Setting up NVIDIA Container Toolkit
distribution=$(. /etc/os-release;echo $ID$VERSION_ID) \
&& curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | apt-key add - \
&& curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | tee /etc/apt/sources.list.d/nvidia-docker.list
# MIG Capability on A100
curl -s -L https://nvidia.github.io/nvidia-container-runtime/experimental/$distribution/nvidia-container-runtime.list | tee /etc/apt/sources.list.d/nvidia-container-runtime.list

apt-get update
# Install nvidia-docker package
# Install NVIDIA container toolkit and mark NVIDIA packages on hold
apt-get install -y nvidia-container-toolkit
apt-mark hold nvidia-container-toolkit
apt-mark hold libnvidia-container-tools
apt-mark hold libnvidia-container1

# Install NVIDIA container runtime and mark NVIDIA packages on hold
apt-get install -y nvidia-container-runtime
apt-mark hold nvidia-container-runtime

wget https://raw.githubusercontent.com/NVIDIA/nvidia-docker/master/nvidia-docker
cp nvidia-docker /bin/
chmod +x /bin/nvidia-docker
wget https://raw.githubusercontent.com/NVIDIA/nvidia-docker/master/daemon.json
cp daemon.json /etc/docker/

# Working setup can be tested by running a base CUDA container
# nvidia-docker run -e NVIDIA_VISIBLE_DEVICES=all nvidia/cuda:11.0-base nvidia-smi

# enable and restart the docker daemon to complete the installation
systemctl enable docker
systemctl restart docker

# Write the docker version to components file
docker_version=$(nvidia-docker --version | awk -F' ' '{print $3}')
$COMMON_DIR/write_component_version.sh "NVIDIA-DOCKER" ${docker_version::-1}
