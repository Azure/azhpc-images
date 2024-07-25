#!/bin/bash
set -ex

# Install Moby Engine + CLI
yum install -y moby-engine
yum install -y moby-cli

$ALMA_COMMON_DIR/install_nvidia_container_toolkit.sh

# enable and restart the docker daemon to complete the installation
systemctl enable docker
systemctl restart docker

$COMMON_DIR/setup_nvidia_containerd.sh

# restart containerd service
systemctl restart containerd

# status of containerd snapshotter plugins
ctr plugin ls

# Clean repos
rm -rf /etc/yum.repos.d/nvidia-*
rm -rf /var/cache/yum/x86_64/8/nvidia-*
rm -rf /var/cache/yum/x86_64/8/libnvidia-container/

# Write the docker version to components file
docker_version=$(docker --version | awk -F' ' '{print $3}')
$COMMON_DIR/write_component_version.sh "DOCKER" ${docker_version::-1}

moby_version=$(yum list installed | grep moby-engine | awk -F' ' '{print $2}')
$COMMON_DIR/write_component_version.sh "MOBY_ENGINE" ${moby_version}
