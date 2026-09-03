#!/bin/bash
set -ex

source ${UTILS_DIR}/utilities.sh

# Install the "Microsoft TLS RSA Root G2" trust anchor before any HTTPS
# calls to Microsoft endpoints.
$COMPONENT_DIR/install_microsoft_tls_root_g2.sh

# Setup microsoft packages repository (PMC publishes packages-microsoft-prod.deb
# for ubuntu/26.04, verified Sep 2026).
curl -fsSL -o packages-microsoft-prod.deb https://packages.microsoft.com/config/ubuntu/26.04/packages-microsoft-prod.deb
dpkg -i packages-microsoft-prod.deb
rm -f packages-microsoft-prod.deb

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
                   dos2unix

# azcopy: Microsoft's PMC ubuntu/26.04/prod pool does not yet ship azcopy
# (verified Sep 2026).
# Install the upstream .deb from the official GitHub releases instead, pinned
# and sha256-verified for reproducibility.
# TODO(ubuntu26.04): once PMC publishes azcopy for 26.04, switch back to
# `apt-get -y install azcopy` to align with the other Ubuntu distros.
AZCOPY_VERSION="10.32.3"
AZCOPY_DEB_URL="https://github.com/Azure/azure-storage-azcopy/releases/download/v${AZCOPY_VERSION}/azcopy-${AZCOPY_VERSION}.x86_64.deb"
AZCOPY_DEB_SHA256="fab3836155cfe2fd250448f875a35dc593c91cd148d4276d39f242ce10ca861c"
curl -fsSL -o azcopy.deb "${AZCOPY_DEB_URL}"
echo "${AZCOPY_DEB_SHA256}  azcopy.deb" | sha256sum --check --strict
apt-get -y install ./azcopy.deb
rm -f azcopy.deb

if sku_uses_ipoib; then
    echo ib_ipoib | sudo tee /etc/modules-load.d/ib_ipoib.conf
fi
echo ib_umad | sudo tee /etc/modules-load.d/ib_umad.conf

# copy kvp client file
$COMPONENT_DIR/copy_kvp_client.sh

# copy torset tool
$COMPONENT_DIR/copy_torset_tool.sh

# Set default shell for newly created users (bash is no longer the default in Canonical's Resolute image for Azure)
sed -i 's|^SHELL=.*|SHELL=/bin/bash|' /etc/default/useradd
