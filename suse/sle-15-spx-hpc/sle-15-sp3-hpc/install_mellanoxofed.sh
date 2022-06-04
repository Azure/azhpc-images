#!/bin/bash
set -ex

MLNX_OFED_DOWNLOAD_URL=http://content.mellanox.com/ofed/MLNX_OFED-${MOFED_VERSION}/MLNX_OFED_LINUX-${MOFED_VERSION}-sles15sp3-x86_64.tgz
TARBALL=$(basename ${MLNX_OFED_DOWNLOAD_URL})
MOFED_FOLDER=$(basename ${MLNX_OFED_DOWNLOAD_URL} .tgz)

$COMMON_DIR/download_and_verify.sh $MLNX_OFED_DOWNLOAD_URL "4790a3196eef0d1266646a8b65f0fa4813e89c508b5f62484053686d6d66932a"
tar zxvf ${TARBALL}

KERNEL=$(uname -r | awk -F- '{print $(NF)}')
if [[ ${KERNEL} == "default" ]]; then \
    KERNEL=""
else
    KERNEL="-${KERNEL}"
fi

KERNEL_VERSION_RELEASE=$(rpm -qa kernel${KERNEL} --queryformat "%{VERSION}-%{RELEASE}")

# remove python2 when mellanox installer issue fixed
zypper install --no-confirm \
    rpm-build \
    insserv-compat \
    kernel-source${KERNEL}-${KERNEL_VERSION_RELEASE} \
    patch \
    make \
    kernel-syms${KERNEL}-${KERNEL_VERSION_RELEASE} \
    python3-devel \
    python2 \
    tk \
    expat \
    createrepo_c

# Error: One or more packages depends on MLNX_OFED_LINUX.
# Those packages should be removed before uninstalling MLNX_OFED_LINUX:

zypper --ignore-unknown remove --no-confirm \
    librdmacm1 \
    srp_daemon \
    rdma-core-devel

./${MOFED_FOLDER}/mlnxofedinstall --add-kernel-support 

echo "\n" >> /etc/modprobe.d/mlnx.conf
echo "\n# blacklist rpcrdma which relies on rdma_cm, conflicts with rdma_ucm" >> /etc/modprobe.d/mlnx.conf
echo "\nblacklist rpcrdma" >> /etc/modprobe.d/mlnx.conf

modprobe -r rpcrdma

systemctl enable openibd
systemctl start openibd
