#!/bin/bash
set -ex

# Install NVIDIA Container Toolkit
tdnf install -y nvidia-container-toolkit

# Mark the installed packages on hold to disable updates
sed -i "$ s/$/ *nvidia-container*/" /etc/dnf/dnf.conf

# Configure NVIDIA Container Toolkit
nvidia-ctk runtime configure --runtime=docker

# Configure containerd to use NVIDIA runtime
mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
sed -i 's/runtime = "runc"/runtime = "nvidia-container-runtime"/g' /etc/containerd/config.toml
# sed -i 's/disabled_plugins = \[\]/disabled_plugins = \["cri", "zfs", "aufs", "btrfs", "devmapper"\]/g' /etc/containerd/config.toml

