#!/bin/bash
set -ex

# Setup microsoft packages repository for moby
# Download the repository configuration package
curl -sSL -O https://packages.microsoft.com/config/ubuntu/24.04/packages-microsoft-prod.deb
# Copy the generated list to the sources.list.d directory
cp ./microsoft-prod.list /etc/apt/sources.list.d/
# Install the Microsoft GPG public key
sudo dpkg -i packages-microsoft-prod.deb
rm packages-microsoft-prod.deb

#apt-get install packages
$UBUNTU_COMMON_DIR/install_utils.sh
