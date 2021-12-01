#!/bin/bash
set -ex

# Install Docker
curl https://get.docker.com | sh && sudo systemctl --now enable docker

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

# Configure docker to not fill up the image disk and to not use the same address space as the IB network
sudo systemctl stop docker
sudo sh -c "echo '{  \"data-root\": \"/mnt/resource/docker\", \"bip\": \"152.26.0.1/16\", \"runtimes\": { \"nvidia\": { \"path\": \"/usr/bin/nvidia-container-runtime\", \"runtimeArgs\": [] } } }' > /etc/docker/daemon.json"

# enable and restart the docker daemon to complete the installation
systemctl enable docker
systemctl restart docker

# Write the docker version to components file
docker_version=$(nvidia-docker --version | awk -F' ' '{print $3}')
$COMMON_DIR/write_component_version.sh "NVIDIA-DOCKER" ${docker_version::-1}
