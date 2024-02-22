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

$COMMON_DIR/install_spack.sh
