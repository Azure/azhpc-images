#!/bin/bash
set -ex

# Install Moby Engine + CLI
yum install -y moby-engine
yum install -y moby-cli

# Install NVIDIA Docker
# Reference: https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html
# Setting up NVIDIA Container Toolkit
distribution=$(. /etc/os-release;echo $ID$VERSION_ID) \
   && curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.repo | tee /etc/yum.repos.d/nvidia-docker.repo
# MIG Capability on A100
curl -s -L https://nvidia.github.io/nvidia-container-runtime/experimental/$distribution/nvidia-container-runtime.list | tee /etc/yum.repos.d/nvidia-container-runtime.list

yum clean expire-cache
# Install nvidia-docker package
# Install NVIDIA container toolkit and mark NVIDIA packages on hold
yum install -y nvidia-container-toolkit
# Mark the installed packages on hold to disable updates
echo "exclude=nvidia-container-toolkit" | tee -a /etc/yum.conf
echo "exclude=libnvidia-container-tools" | tee -a /etc/yum.conf
echo "exclude=libnvidia-container1" | tee -a /etc/yum.conf

# Install NVIDIA container runtime and mark NVIDIA packages on hold
yum install -y nvidia-container-runtime
echo "exclude=nvidia-container-runtime" | tee -a /etc/yum.conf

wget https://raw.githubusercontent.com/NVIDIA/nvidia-docker/master/nvidia-docker
cp nvidia-docker /bin/
chmod +x /bin/nvidia-docker
wget https://raw.githubusercontent.com/NVIDIA/nvidia-docker/master/daemon.json
cp daemon.json /etc/docker/

# Working setup can be tested by running a base CUDA container
# nvidia-docker run -e NVIDIA_VISIBLE_DEVICES=all nvidia/cuda:11.0-base nvidia-smi

# enable and restart the docker daemon to complete the installation
systemctl enable docker
systemctl restart docker

# Write the docker version to components file
docker_version=$(nvidia-docker --version | awk -F' ' '{print $3}')
$COMMON_DIR/write_component_version.sh "NVIDIA-DOCKER" ${docker_version::-1}
