#!/bin/bash
set -ex

# Install Moby Engine + CLI
yum install -y moby-engine
yum install -y moby-cli

# Install NVIDIA Docker
# Reference: https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html
# Setting up NVIDIA Container Toolkit
case ${DISTRIBUTION} in
    "almalinux8.6") distribution="rhel8.6"
        ;;
    "almalinux8.7") distribution="rhel8.7";
        ;;
    *) ;;
esac

curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.repo | tee /etc/yum.repos.d/nvidia-docker.repo
# MIG Capability on A100
# curl -s -L https://nvidia.github.io/nvidia-container-runtime/experimental/$distribution/nvidia-container-runtime.list | tee /etc/yum.repos.d/nvidia-container-runtime.list

yum clean expire-cache
# Install nvidia-docker package
# Install NVIDIA container toolkit and mark NVIDIA packages on hold
yum install -y nvidia-container-toolkit

# Install NVIDIA container runtime and mark NVIDIA packages on hold
yum install -y nvidia-container-runtime
# Mark the installed packages on hold to disable updates
sed -i "$ s/$/ *nvidia-container*/" /etc/dnf/dnf.conf

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
docker_version=$(nvidia-docker --version | awk -F' ' '{print $3}')
$COMMON_DIR/write_component_version.sh "NVIDIA-DOCKER" ${docker_version::-1}

# Clean repos
rm -rf /etc/yum.repos.d/nvidia-*
rm -rf /var/cache/yum/x86_64/8/nvidia-*
rm -rf /var/cache/yum/x86_64/8/libnvidia-container/
