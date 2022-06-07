#!/bin/bash
set -ex

MLNX_OFED_DOWNLOAD_URL=http://content.mellanox.com/ofed/MLNX_OFED-${MOFED_VERSION}/MLNX_OFED_LINUX-${MOFED_VERSION}-sles15sp3-x86_64.tgz
TARBALL=$(basename ${MLNX_OFED_DOWNLOAD_URL})
MOFED_FOLDER=$(basename ${MLNX_OFED_DOWNLOAD_URL} .tgz)

if ! [[ -f ${TARBALL} ]]; then
    $COMMON_DIR/download_and_verify.sh $MLNX_OFED_DOWNLOAD_URL "237d989373f13f33a75806c5035da342247290cff9ab07f5c5c475e6517288c4"
fi

if ! [[ -d ${MOFED_FOLDER} ]]; then
    tar zxvf ${TARBALL}
fi

# mellanox installer dependencies
zypper install --no-confirm \
    rpm-build \
    insserv-compat \
    patch \
    make \
    python3-devel \
    tk \
    expat \
    createrepo_c

# running kernel might be older, force install earlier version.
# consider rebooting with latest kernel prior
zypper install --no-confirm --force \
    kernel-source${KERNEL_FLAVOR}-${KERNEL_VERSION_RELEASE} \
    kernel-syms${KERNEL_FLAVOR}-${KERNEL_VERSION_RELEASE}

# mlnxofedinstall requires kernel-source installed regardless of kernel flavor
if ! [[ ${KERNEL} -ne "default" ]]; then
    zypper install --no-confirm \
        kernel-source
fi

# Error: One or more packages depends on MLNX_OFED_LINUX.
# Those packages should be removed before uninstalling MLNX_OFED_LINUX:
zypper --ignore-unknown remove --no-confirm \
    librdmacm1 \
    srp_daemon \
    rdma-core-devel

./${MOFED_FOLDER}/mlnxofedinstall --add-kernel-support 

# You may need to update your initramfs before next boot. To do that, run:
# dracut -f
dracut -f

echo "\n" >> /etc/modprobe.d/mlnx.conf
echo "\n# blacklist rpcrdma which relies on rdma_cm, conflicts with rdma_ucm" >> /etc/modprobe.d/mlnx.conf
echo "\nblacklist rpcrdma" >> /etc/modprobe.d/mlnx.conf

modprobe -r rpcrdma

systemctl enable openibd
systemctl start openibd
