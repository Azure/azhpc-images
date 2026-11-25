#!/bin/bash
set -ex

# Setup microsoft packages repository
curl -sSL -O https://packages.microsoft.com/config/$(. /etc/os-release;echo $ID/$VERSION_ID)/packages-microsoft-prod.deb
apt install -y ./packages-microsoft-prod.deb
apt-get update

# Remove the downloaded package
rm -rf packages-microsoft-prod.deb

apt-get -y install build-essential
apt-get -y install net-tools \
                   infiniband-diags \
                   jq 

$COMPONENT_DIR/install_cuda_repo_and_dkms.sh

echo ib_ipoib | sudo tee /etc/modules-load.d/ib_ipoib.conf
