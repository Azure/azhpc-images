#!/bin/bash
set -ex

# Setup microsoft packages repository
curl -sSL -O https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb
dpkg -i packages-microsoft-prod.deb
rm packages-microsoft-prod.deb

#apt-get install packages

$UBUNTU_COMMON_DIR/install_utils.sh
