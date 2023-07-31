#!/bin/bash
set -ex

# Install common dependencies
$COMMON_DIR/install_utils.sh

# Setup microsoft packages repository for moby
# Download the repository configuration package
. /etc/os-release
curl https://packages.microsoft.com/config/ubuntu/$VERSION_ID/prod.list > ./microsoft-prod.list
# Copy the generated list to the sources.list.d directory
cp ./microsoft-prod.list /etc/apt/sources.list.d/
# Install the Microsoft GPG public key
curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg
cp ./microsoft.gpg /etc/apt/trusted.gpg.d/

apt-get update
apt-get install -y libnuma-dev \
    python3-pip \
    net-tools \
    libnl-3-dev \
    libnl-route-3-dev \
    libnl-3-200 \
    libnl-genl-3-dev \
    libnl-genl-3-200 \
    libnl-route-3-200 \
    libnl-3-dev \
    libnl-route-3-dev \
    libyaml-dev \
    libreadline-dev \
    libkeyutils1 \
    libkeyutils-dev \
    libmount-dev \
    nfs-common \
    libiberty-dev

# copy kvp client file
$COMMON_DIR/copy_kvp_client.sh
