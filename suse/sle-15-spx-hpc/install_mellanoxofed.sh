#!/bin/bash
set -ex

MLNX_OFED_DOWNLOAD_URL=http://content.mellanox.com/ofed/MLNX_OFED-5.6-1.0.3.3/MLNX_OFED_LINUX-5.6-1.0.3.3-sles15sp3-x86_64.tgz
TARBALL=$(basename ${MLNX_OFED_DOWNLOAD_URL})
MOFED_FOLDER=$(basename ${MLNX_OFED_DOWNLOAD_URL} .tgz)

$COMMON_DIR/download_and_verify.sh $MLNX_OFED_DOWNLOAD_URL "4790a3196eef0d1266646a8b65f0fa4813e89c508b5f62484053686d6d66932a"
tar zxvf ${TARBALL}

KERNEL=( $(uname -r | awk -F- '{print $(NF)}') )
if [[ ${KERNEL} == "default" ]]; then \
    KERNEL=""
else
    KERNEL="-${KERNEL}"
fi

echo ${KERNEL}

zypper install --no-confirm \
    rpm-build \
    insserv-compat \
    kernel-source \
    kernel-source${KERNEL} \
    patch \
    make \
    kernel-syms${KERNEL} \
    python3-devel \
    python2 \ # remove when mellanox installer issue fixed
    tk \
    expat

./${MOFED_FOLDER}/mlnxofedinstall --add-kernel-support 

echo "\n" >> /etc/modprobe.d/mlnx.conf
echo "\nblacklist rpcrdma which relies on rdma_cm, conflicts with rdma_ucm" >> /etc/modprobe.d/mlnx.conf
echo "\nblacklist rpcrdma" >> /etc/modprobe.d/mlnx.conf

tmodprobe -r rpcrdma

systemctl enable openibd
systemctl start openibd

# Initializing...
# Attempting to perform Firmware update...
# You may need to update your initramfs before next boot. To do that, run:
