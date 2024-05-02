#!/bin/bash
set -ex

# Install Moby Engine + CLI
tdnf install -y moby-engine
tdnf install -y moby-cli

# Install NVIDIA Docker
# Reference: https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html
# Setting up NVIDIA Container Toolkit

curl -s -L https://nvidia.github.io/libnvidia-container/stable/rpm/nvidia-container-toolkit.repo | tee /etc/yum.repos.d/nvidia-container-toolkit.repo
# MIG Capability on A100
# curl -s -L https://nvidia.github.io/nvidia-container-runtime/experimental/$distribution/nvidia-container-runtime.list | tee /etc/yum.repos.d/nvidia-container-runtime.list

# Install NVIDIA container toolkit
tdnf install --noplugins -y nvidia-container-toolkit

# Install NVIDIA container runtime
tdnf install --noplugins -y nvidia-container-runtime
# Mark the installed packages on hold to disable updates
sed -i "$ s/$/ *nvidia-container*/" /etc/dnf/dnf.conf

nvidia-ctk runtime configure --runtime=docker

# enable and restart the docker daemon to complete the installation
systemctl enable docker
systemctl restart docker

# Working setup can be tested by running a base CUDA container
# nvidia-docker run -e NVIDIA_VISIBLE_DEVICES=all nvidia/cuda:11.0-base nvidia-smi

nvidia-ctk runtime configure --runtime=containerd

# restart containerd service
systemctl restart containerd

# status of containerd snapshotter plugins
ctr plugin ls

# Write the docker version to components file
docker_version=$(docker --version | awk -F' ' '{print $3}')
$COMMON_DIR/write_component_version.sh "docker" ${docker_version::-1}

# Clean repos
rm -rf /etc/yum.repos.d/nvidia-*
rm -rf /var/cache/yum/x86_64/8/nvidia-*
rm -rf /var/cache/yum/x86_64/8/libnvidia-container/
