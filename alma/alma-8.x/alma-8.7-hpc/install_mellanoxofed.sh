#!/bin/bash
set -ex

mofed_metadata=$(jq -r '.mofed."'"$DISTRIBUTION"'"' <<< $COMPONENT_VERSIONS)
mofed_version=$(jq -r '.version' <<< $mofed_metadata)
mofed_sha256=$(jq -r '.sha256' <<< $mofed_metadata)
tarball="MLNX_OFED_LINUX-$mofed_version-rhel8.7-x86_64.tgz"
mofed_download_url=https://content.mellanox.com/ofed/MLNX_OFED-$mofed_version/$tarball
mofed_folder=$(basename $mofed_download_url .tgz)

$COMMON_DIR/download_and_verify.sh $mofed_download_url $mofed_sha256
tar zxvf $tarball

./$mofed_folder/mlnxofedinstall --kernel $KERNEL --kernel-sources /usr/src/kernels/$KERNEL --add-kernel-support --skip-repo --skip-unsupported-devices-check --without-fw-update --distro rhel8.7
$COMMON_DIR/write_component_version.sh "mofed" $mofed_version

# Restarting openibd
/etc/init.d/openibd restart

# exclude opensm from updates
sed -i "$ s/$/ opensm*/" /etc/dnf/dnf.conf

# cleanup downloaded files
rm -rf *.tgz
rm -rf -- */
