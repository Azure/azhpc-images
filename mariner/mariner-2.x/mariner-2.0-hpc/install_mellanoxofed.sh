#!/bin/bash
set -ex

# Packages for MOFED
tdnf install -y iptables-devel \
    libdb-devel \
    libmnl-devel \
    libgudev \
    fuse-devel \
    libgudev-devel \
    pciutils-devel \
    libusb \
    openssl-devel \
    libusb-devel \
    flex \
    lsof \
    automake \
    autoconf


# TEMP
tdnf install -y bison \
    cmake

mofed_metadata=$(jq -r '.mofed."'"$DISTRIBUTION"'"' <<< $COMPONENT_VERSIONS)
mofed_version=$(jq -r '.version' <<< $mofed_metadata)
mofed_sha256=$(jq -r '.sha256' <<< $mofed_metadata)
tarball="MLNX_OFED_SRC-$mofed_version.tgz"
mofed_download_url=https://www.mellanox.com/downloads/ofed/MLNX_OFED-$mofed_version/$tarball
mofed_folder=$(basename $mofed_download_url .tgz)
kernel_without_arch="${KERNEL%.*}"

$COMMON_DIR/download_and_verify.sh $mofed_download_url $mofed_sha256
tar zxvf $tarball

pushd $mofed_folder
./install.pl --all --without-openmpi --without-mlnx-ofa_kernel-modules
popd
$COMMON_DIR/write_component_version.sh "mofed" $mofed_version

# Restarting openibd
/etc/init.d/openibd restart

# exclude opensm from updates
sed -i "$ s/$/ opensm*/" /etc/dnf/dnf.conf

# cleanup downloaded files
rm -rf *.tgz
rm -rf -- */
