#!/bin/bash
set -ex

wget http://content.mellanox.com/ofed/MLNX_OFED-5.0-2.1.8.0/MLNX_OFED_LINUX-5.0-2.1.8.0-rhel7.6-x86_64.tgz
tar zxvf MLNX_OFED_LINUX-5.0-2.1.8.0-rhel7.6-x86_64.tgz

KERNEL=( $(rpm -q kernel | sed 's/kernel\-//g') )
KERNEL=${KERNEL[-1]}
yum -y install http://olcentgbl.trafficmanager.net/centos/7.6.1810/updates/x86_64/kernel-devel-${KERNEL}.rpm
./MLNX_OFED_LINUX-5.0-2.1.8.0-rhel7.6-x86_64/mlnxofedinstall --kernel $KERNEL --kernel-sources /usr/src/kernels/${KERNEL} --add-kernel-support --skip-repo
