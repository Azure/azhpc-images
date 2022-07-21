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

apt-get -y install build-essential
apt-get -y install numactl \
                   rpm \
                   libnuma-dev \
                   libmpc-dev \
                   libmpfr-dev \
                   libxml2-dev \
                   m4 \
                   byacc \
                   python-dev \
                   python-setuptools \
                   tcl \
                   environment-modules \
                   tk \
                   texinfo \
                   libudev-dev \
                   binutils \
                   binutils-dev \
                   selinux-policy-dev \
                   flex \
                   libnl-3-dev \
                   libnl-route-3-dev \
                   libnl-3-200 \
                   bison \
                   libnl-route-3-200 \
                   gfortran \
                   cmake \
                   libnl-3-dev \
                   libnl-route-3-dev \
                   libsecret-1-0 \
		   ansible \
                   dkms

# Install azcopy tool 
# To copy blobs or files to or from a storage account.
wget https://azcopyvnextrelease.blob.core.windows.net/release20210920/azcopy_linux_se_amd64_10.12.2.tar.gz
tar -xvf azcopy_linux_se_amd64_10.12.2.tar.gz

# copy the azcopy to the bin path
pushd azcopy_linux_se_amd64_10.12.2
cp azcopy /usr/bin/
popd

# Allow execute permissions
chmod +x /usr/bin/azcopy
