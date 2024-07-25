#!/bin/bash
set -ex

# Install NVIDIA Container Toolkit
# Reference: https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html
# Setting up NVIDIA Container Toolkit
curl -s -L https://nvidia.github.io/libnvidia-container/stable/rpm/nvidia-container-toolkit.repo | \
  sudo tee /etc/yum.repos.d/nvidia-container-toolkit.repo

yum-config-manager --enable nvidia-container-toolkit-experimental

yum clean expire-cache
yum install -y nvidia-container-toolkit

# Mark the installed packages on hold to disable updates
sed -i "$ s/$/ *nvidia-container*/" /etc/dnf/dnf.conf

# Configure NVIDIA Container Toolkit
nvidia-ctk runtime configure --runtime=docker
