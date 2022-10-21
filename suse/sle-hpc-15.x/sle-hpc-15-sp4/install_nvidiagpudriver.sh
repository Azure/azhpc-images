#!/bin/bash
set -ex

#
## Nvidia provide certified packages for SLES 15 SP4, so we only need to add the repositories and install the packages
#

# Install Cuda
#NVIDIA_VERSION="520.61"
#CUDA_VERSION="11.8.0"

# to check whats all available in the repo
# zypper se --repo cuda-sles15-x86_64

# install latest cuda package
# the repo contains more versions, so for example we want cuda 11.3 the package name is "cuda-11-3"
zypper install -y -l cuda cuda-drivers

CUDA_VERSION=$(rpm -q --qf="%{VERSION}" cuda)
$COMMON_DIR/write_component_version.sh "CUDA" ${CUDA_VERSION}

NVIDIA_VERSION=$(rpm -q --qf="%{VERSION}" cuda-drivers)
$COMMON_DIR/write_component_version.sh "NVIDIA" ${NVIDIA_VERSION}

# Post-install tasks (version its set through 'alternatives')
echo 'export PATH=$PATH:/usr/local/cuda/bin' | tee -a /etc/bash.bashrc.local
echo 'export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/cuda/lib64' | tee -a /etc/bash.bashrc.local