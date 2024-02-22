#!/bin/bash
set -ex

# dependencies for spack installation
# Ref: https://spack.readthedocs.io/en/latest/getting_started.html
dnf group install "Development Tools" -y
dnf install -y curl \
    findutils \
    gcc-gfortran \
    gnupg2 \
    hostname \
    iproute \
    redhat-lsb-core \
    python3 \
    python3-pip \
    python3-setuptools \
    unzip
dnf --enablerepo=ha install -y python3-boto3

$COMMON_DIR/install_spack.sh
