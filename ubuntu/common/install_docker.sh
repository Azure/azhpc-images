#!/bin/bash
set -ex

# Reference: https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html
# Setting up docker
curl https://get.docker.com | sh \
&& systemctl --now enable docker

# Setting up NVIDIA Container Toolkit
distribution=$(. /etc/os-release;echo $ID$VERSION_ID) \
&& curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | apt-key add - \
&& curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | tee /etc/apt/sources.list.d/nvidia-docker.list
# MIG Capability on A100
curl -s -L https://nvidia.github.io/nvidia-container-runtime/experimental/$distribution/nvidia-container-runtime.list | tee /etc/apt/sources.list.d/nvidia-container-runtime.list

# Install nvidia-docker2 package
apt-get update
apt-get install -y nvidia-docker2

# Mark the installed packages on hold to disable updates
apt-mark hold libnvidia-container-tools
apt-mark hold libnvidia-container1
apt-mark hold nvidia-container-runtime
apt-mark hold nvidia-container-toolkit
apt-mark hold nvidia-docker2

# restart the docker daemon to complete the installation
systemctl restart docker
