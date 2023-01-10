#!/bin/bash
set -ex

# SLES comes with mellanox inbox (kernel) drivers by default, so no need to install anything
#

# the ibdev2netdev is only in the external mellanox package, so we do not have it with inbox drivers
wget https://raw.githubusercontent.com/Mellanox/container_scripts/master/ibdev2netdev
mv ibdev2netdev /usr/local/bin
chmod +x /usr/local/bin/ibdev2netdev

# IF you want the external drivers provided by https://network.nvidia.com/products/infiniband-drivers/linux/mlnx_ofed/
# it provides packages for SLES with MLNX_OFED_LINUX-5.7-1.0.2.0-sles15sp4-x86_64.tgz
# SHA256: f3af9dd691dc07404fa07a1c3819de14361dc292d90a9b81aac6a7c729a2ea0f
# you need to agree to the eula and provide the file somewhere

#MLNX_OFED_DOWNLOAD_URL=https://content.mellanox.com/ofed/MLNX_OFED-5.7-1.0.2.0/MLNX_OFED_LINUX-5.7-1.0.2.0-sles15sp4-x86_64.tgz
#TARBALL=$(basename ${MLNX_OFED_DOWNLOAD_URL})
#MOFED_FOLDER=$(basename ${MLNX_OFED_DOWNLOAD_URL} .tgz)

#$COMMON_DIR/download_and_verify.sh $MLNX_OFED_DOWNLOAD_URL "f3af9dd691dc07404fa07a1c3819de14361dc292d90a9b81aac6a7c729a2ea0f"
#tar zxvf ${TARBALL}

# SUSE - if you use the tarball
# The tarball contains modules for SLES default kernel already, there is no need for adding additional parameters to the installscript
# but our default for SLES HPC is the -azure kernel, so we need to add it or switch to kernel-default.

# SUSE default kernel would be simply:
#./${MOFED_FOLDER}/mlnxofedinstall

# SUSE azure kernel (manual check before if kernel and kernel-src fit together, could be not the same due to updates)
#KERNEL=$(uname -r)
#zypper in -y -l kernel-azure-devel kernel-source-azure
#make -C /usr/src/linux-azure oldconfig
#./${MOFED_FOLDER}/mlnxofedinstall --kernel $KERNEL --kernel-sources /usr/src/linux-${KERNEL} --add-kernel-support --skip-repo
