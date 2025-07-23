#!/bin/bash
set -ex

# Install Moby Engine + CLI
tdnf install -y moby-engine
tdnf install -y moby-cli

# Install NVIDIA container toolkit
tdnf install --noplugins -y nvidia-container-toolkit-base nvidia-container-toolkit

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
mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml  
nvidia-ctk runtime configure --runtime=containerd

# restart containerd service
systemctl restart containerd

# status of containerd snapshotter plugins
ctr plugin ls

# Write the docker version to components file
docker_version=$(docker --version | awk -F' ' '{print $3}')
$COMMON_DIR/write_component_version.sh "docker" ${docker_version::-1}

moby_engine_version=$(rpm -qa | grep moby | cut -d'-' -f3,4)
$COMMON_DIR/write_component_version.sh "MOBY_ENGINE" ${moby_engine_version::-12}
