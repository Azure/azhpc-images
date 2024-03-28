#!/bin/bash
set -ex

# Setup microsoft packages repository for moby
# Download the repository configuration package
curl https://packages.microsoft.com/config/ubuntu/22.04/prod.list > ./microsoft-prod.list
# Copy the generated list to the sources.list.d directory
cp ./microsoft-prod.list /etc/apt/sources.list.d/
# Install the Microsoft GPG public key
curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg
cp ./microsoft.gpg /etc/apt/trusted.gpg.d/

# upgrade pre-installed components
apt update

# install LTS kernel
apt install -y linux-azure-lts

# jq is needed to parse the component versions from the requirements.json file
apt install -y jq
