#!/bin/bash
set -ex

# Setup microsoft packages repository
curl -sSL -O https://packages.microsoft.com/config/$(. /etc/os-release;echo $ID/$VERSION_ID)/packages-microsoft-prod.deb
dpkg -i packages-microsoft-prod.deb
apt-get update

# Remove the downloaded package
rm -rf packages-microsoft-prod.deb

apt-get -y install build-essential
apt-get -y install net-tools \
                   infiniband-diags \
                   dkms \
                   jq 

echo ib_ipoib | sudo tee /etc/modules-load.d/ib_ipoib.conf