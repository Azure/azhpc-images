#!/bin/bash
set -ex

# dependencies for spack installation
# Ref: https://spack.readthedocs.io/en/latest/getting_started.html
# dnf group install "Development Tools" -y
# Group unavailable in so installing required individual packages
tdnf install -y build-essential \
    gdb \
    git \
    lmdb-devel \
    patchutils  

tdnf install -y gcc-gfortran \
    python3-pip \
    unzip

$COMMON_DIR/install_spack.sh
