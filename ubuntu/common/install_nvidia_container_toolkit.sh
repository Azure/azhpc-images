#!/bin/bash
set -ex

# Install NVIDIA Container Toolkit
# Reference: https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html
# Setting up NVIDIA Container Toolkit
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
  && curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

sed -i -e '/experimental/ s/^#//g' /etc/apt/sources.list.d/nvidia-container-toolkit.list

apt-get update
# Install NVIDIA container toolkit and mark NVIDIA packages on hold
apt-get install -y nvidia-container-toolkit
apt-mark hold nvidia-container-toolkit
apt-mark hold libnvidia-container-tools
apt-mark hold libnvidia-container1

# Configure NVIDIA Container Toolkit
nvidia-ctk runtime configure --runtime=docker
