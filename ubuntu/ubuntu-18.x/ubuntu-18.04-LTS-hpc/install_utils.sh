#!/bin/bash
set -ex

# Setup microsoft packages repository for moby
# Download the repository configuration package
curl https://packages.microsoft.com/config/ubuntu/18.04/prod.list > ./microsoft-prod.list
# Copy the generated list to the sources.list.d directory
cp ./microsoft-prod.list /etc/apt/sources.list.d/
# Install the Microsoft GPG public key
curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg
cp ./microsoft.gpg /etc/apt/trusted.gpg.d/

#apt-get install packages
AZCOPY_VERSION="10.17.0"
AZCOPY_RELEASE_TAG="release20230123"
$UBUNTU_COMMON_DIR/install_utils.sh ${AZCOPY_VERSION} ${AZCOPY_RELEASE_TAG}
