#!/bin/bash
set -ex

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
                   python3-pip \
                   dkms \
                   jq \
                   curl \
                   libyaml-dev \
                   libreadline-dev \
                   libkeyutils1 \
                   libkeyutils-dev \
                   libmount-dev \
                   nfs-common \
                   pssh

if [[ $DISTRIBUTION != "ubuntu22.04" ]]; then apt-get install -y python-dev; fi

# Install azcopy tool
# To copy blobs or files to or from a storage account
azcopy_metadata=$(jq -r '.azcopy."'"$DISTRIBUTION"'"' <<< $COMPONENT_VERSIONS)
azcopy_version=$(jq -r '.version' <<< $azcopy_metadata)
azcopy_release=$(jq -r '.release' <<< $azcopy_metadata)
azcopy_sha256=$(jq -r '.sha256' <<< $azcopy_metadata)
TARBALL="azcopy_linux_amd64_$azcopy_version.tar.gz"
AZCOPY_DOWNLOAD_URL="https://azcopyvnext.azureedge.net/$azcopy_release/$TARBALL"
wget ${AZCOPY_DOWNLOAD_URL}
tar -xvf ${TARBALL}

# copy the azcopy to the bin path
pushd azcopy_linux_amd64_${azcopy_version}
cp azcopy /usr/bin/
popd

# Allow execute permissions
chmod +x /usr/bin/azcopy

# remove tarball from azcopy
rm -rf *.tar.gz

# copy kvp client file
$COMMON_DIR/copy_kvp_client.sh
