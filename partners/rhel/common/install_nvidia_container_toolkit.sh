#!/bin/bash
set -ex

# Install NVIDIA Container Toolkit
# Reference: https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html
# Setting up NVIDIA Container Toolkit
curl -s -L https://nvidia.github.io/libnvidia-container/stable/rpm/nvidia-container-toolkit.repo | \
  sudo tee /etc/yum.repos.d/nvidia-container-toolkit.repo

dnf config-manager --set-enabled nvidia-container-toolkit-experimental

dnf clean expire-cache
dnf install -y nvidia-container-toolkit

# Mark the installed packages on hold to disable updates
dnf versionlock add "*nvidia-container*"

# Configure NVIDIA Container Toolkit
nvidia-ctk runtime configure --runtime=docker

# Configure containerd to use NVIDIA runtime
mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
sed -i 's/runtime = "runc"/runtime = "nvidia-container-runtime"/g' /etc/containerd/config.toml
# sed -i 's/disabled_plugins = \[\]/disabled_plugins = \["cri", "zfs", "aufs", "btrfs", "devmapper"\]/g' /etc/containerd/config.toml

# Clean repos
rm -rf /etc/yum.repos.d/nvidia-*
rm -rf /var/cache/dnf/*/nvidia-*
rm -rf /var/cache/dnf/*/libnvidia-container/