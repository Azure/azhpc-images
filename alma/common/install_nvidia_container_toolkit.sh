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

# Configure containerd to use NVIDIA runtime
mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
sed -i 's/runtime = "runc"/runtime = "nvidia-container-runtime"/g' /etc/containerd/config.toml
# sed -i 's/disabled_plugins = \[\]/disabled_plugins = \["cri", "zfs", "aufs", "btrfs", "devmapper"\]/g' /etc/containerd/config.toml

# Clean repos
rm -rf /etc/yum.repos.d/nvidia-*
rm -rf /var/cache/yum/x86_64/8/nvidia-*
rm -rf /var/cache/yum/x86_64/8/libnvidia-container/