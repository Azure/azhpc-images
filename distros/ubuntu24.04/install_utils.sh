#!/bin/bash
set -ex

# Setup microsoft packages repository
curl -sSL -O https://packages.microsoft.com/config/ubuntu/24.04/packages-microsoft-prod.deb
dpkg -i packages-microsoft-prod.deb
rm packages-microsoft-prod.deb

apt-get update
apt-get -y install build-essential
apt-get -y install numactl \
                   rpm \
                   libnuma-dev \
                   libmpc-dev \
                   libmpfr-dev \
                   libxml2-dev \
                   m4 \
                   byacc \
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
                   libnl-genl-3-dev \
                   libnl-genl-3-200 \
                   bison \
                   libnl-route-3-200 \
                   gfortran \
                   cmake \
                   libnl-3-dev \
                   libnl-route-3-dev \
                   net-tools \
                   libsecret-1-0 \
                   python3 \
                   python3-pip \
                   python3-setuptools \
                   dkms \
                   jq \
                   curl \
                   libyaml-dev \
                   libreadline-dev \
                   libkeyutils1 \
                   libkeyutils-dev \
                   libmount-dev \
                   nfs-common \
                   pssh \
                   dos2unix \
                   azcopy

echo ib_ipoib | sudo tee /etc/modules-load.d/ib_ipoib.conf
echo ib_umad | sudo tee /etc/modules-load.d/ib_umad.conf

# copy kvp client file
$COMPONENT_DIR/copy_kvp_client.sh

# copy torset tool
$COMPONENT_DIR/copy_torset_tool.sh

# Set default shell for newly created users (somehow bash is no longer the default in Canonical's Noble image for Azure)
sed -i 's|^SHELL=.*|SHELL=/bin/bash|' /etc/default/useradd
