#!/bin/bash
set -ex

apt update -y

# dependencies for spack installation
# Ref: https://spack.readthedocs.io/en/latest/getting_started.html
apt install -y build-essential \
    ca-certificates \
    coreutils \
    curl \
    environment-modules \
    gfortran \
    git \
    gpg \
    lsb-release \
    python3 \
    python3-distutils \
    python3-venv \
    unzip \
    zip \
    jq

## Environment setup for Component installations using Spack
# Create a directory to setup an environment
mkdir -p $HPC_ENV

# Clone Spack into HPC Directory
git clone -c feature.manyFiles=true https://github.com/spack/spack.git $HPC_ENV/spack
spack_branch=$(jq -r '.spack."'"$DISTRIBUTION"'".branch' $TOP_DIR/requirements.json)
pushd $HPC_ENV/spack
git checkout $spack_branch
popd

# Set environment variables
source_spack_env=". $HPC_ENV/spack/share/spack/setup-env.sh"
eval $source_spack_env
# Preserve Spack environment on reboots
echo $source_spack_env | tee -a /etc/bash.bashrc

# Create an environment/ container in /opt
spack env create -d $HPC_ENV
