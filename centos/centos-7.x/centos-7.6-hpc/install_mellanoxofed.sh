#!/bin/bash
set -ex

MLNX_OFED_DOWNLOAD_URL=http://content.mellanox.com/ofed/MLNX_OFED-5.0-2.1.8.0/MLNX_OFED_LINUX-5.0-2.1.8.0-rhel7.6-x86_64.tgz
$COMMON_DIR/download_and_verify.sh $MLNX_OFED_DOWNLOAD_URL "4de233530c4a210142d5a71549b49697e4236c5a05a513256ee3c43e46e82e33"
tar zxvf MLNX_OFED_LINUX-5.0-2.1.8.0-rhel7.6-x86_64.tgz

KERNEL=( $(rpm -q kernel | sed 's/kernel\-//g') )
KERNEL=${KERNEL[-1]}
yum install -y kernel-devel-${KERNEL}
./MLNX_OFED_LINUX-5.0-2.1.8.0-rhel7.6-x86_64/mlnxofedinstall --kernel $KERNEL --kernel-sources /usr/src/kernels/${KERNEL} --add-kernel-support --skip-repo
