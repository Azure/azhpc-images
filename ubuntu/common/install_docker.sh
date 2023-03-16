#!/bin/bash
set -ex

# Install Moby Engine and CLI
apt-get install -y moby-engine

# Install NVIDIA Docker
# Reference: https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html
# Setting up NVIDIA Container Toolkit
curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | apt-key add - \
&& curl -s -L https://nvidia.github.io/nvidia-docker/${DISTRIBUTION}/nvidia-docker.list | tee /etc/apt/sources.list.d/nvidia-docker.list
# MIG Capability on A100
curl -s -L https://nvidia.github.io/nvidia-container-runtime/experimental/${DISTRIBUTION}/nvidia-container-runtime.list | tee /etc/apt/sources.list.d/nvidia-container-runtime.list

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

# disabling aufs, btrfs, zfs and devmapper snapshotter plugins
mkdir -p /etc/containerd
cat << EOF | tee -a /etc/containerd/config.toml
disabled_plugins = ["cri", "zfs", "aufs", "btrfs", "devmapper"]
EOF

# restart containerd service
systemctl restart containerd

# status of containerd snapshotter plugins
ctr plugin ls

# enable and restart the docker daemon to complete the installation
systemctl enable docker
systemctl restart docker

# Write the docker version to components file
moby_version=$(apt list --installed | grep moby-engine | awk -F' ' '{print $2}')
docker_version=$(nvidia-docker --version | awk -F' ' '{print $3}')
$COMMON_DIR/write_component_version.sh "MOBY-ENGINE" ${moby_version}
$COMMON_DIR/write_component_version.sh "NVIDIA-DOCKER" ${docker_version::-1}

# Remove unwanted repos
rm -f /etc/apt/sources.list.d/nvidia*
