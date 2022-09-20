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

#install apt pckages
$UBUNTU_COMMON_DIR/install_utils.sh

apt-get update
apt-get install -y python3.8
update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.8 1
apt-get -y remove python3-apt
apt-get -y install python3-apt

apt-get -y install python3-pip
DISTPACK=/usr/lib/python3/dist-packages
cp $DISTPACK/apt_pkg.cpython-36m-x86_64-linux-gnu.so $DISTPACK/apt_pkg.so
apt-get install -y libcairo2-dev
apt-get install -y python3-dev
apt-get install -y libpython3.8-dev
apt-get install -y libgirepository1.0-dev
python3.8 -m pip install --ignore-installed PyGObject
apt-get install -y software-properties-common
