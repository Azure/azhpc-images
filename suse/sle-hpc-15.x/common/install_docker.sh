#!/bin/bash
set -ex

# Install docker
zypper --non-interactive in -y -l docker

DOCKER_VERSION=$(rpm -q --qf="%{VERSION}" docker)

# Ensure the Docker service is running
systemctl --now enable docker

# if experimental is needed
#zypper modifyrepo --enable libnvidia-container-experimental

zypper --non-interactive install -y -l --replacefiles nvidia-docker2 nvidia-container-runtime

systemctl restart docker

# Test with
#docker run --rm --gpus all nvidia/cuda:11.0.3-base-ubuntu20.04 nvidia-smi

# Write the docker version to components file
$COMMON_DIR/write_component_version.sh "NVIDIA-DOCKER" ${DOCKER_VERSION}
