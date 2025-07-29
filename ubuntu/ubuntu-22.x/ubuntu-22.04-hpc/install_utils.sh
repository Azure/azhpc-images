#!/bin/bash
set -ex

# Setup microsoft packages repository for moby
# Download the repository configuration package
curl https://packages.microsoft.com/config/ubuntu/22.04/prod.list > ./microsoft-prod.list
# Copy the generated list to the sources.list.d directory
cp ./microsoft-prod.list /etc/apt/sources.list.d/
# Install the Microsoft GPG public key
# Technically, per Debian Wiki guidance, this GPG isn't managed by a package, so it should go
# into /etc/apt/keyrings, but this is what the above microsoft-prod.list expects in its signed-by
curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /usr/share/keyrings/microsoft-prod.gpg

#apt-get install packages

$UBUNTU_COMMON_DIR/install_utils.sh
