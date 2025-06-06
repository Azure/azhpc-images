#!/bin/bash
set -ex

source ${COMMON_DIR}/utilities.sh

tdnf install -y azurelinux-repos-extended
tdnf repolist --refresh

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

mofed_metadata=$(get_component_config "mofed")
MOFED_VERSION=$(jq -r '.version' <<< $mofed_metadata)

tdnf install -y libibumad \
                infiniband-diags \
                libibverbs \
                libibverbs-utils \
                ofed-scripts \
                mlnx-tools \
                librdmacm \
                librdmacm-utils \
                rdma-core \
                rdma-core-devel \
                mlnx-ofa_kernel \
                mlnx-ofa_kernel-modules \
                mlnx-ofa_kernel-devel \
                mlnx-ofa_kernel-source \
                mft_kernel \
                mstflint \
                fwctl \
                ibacm \
                ibarr \
                ibsim \
                iser \
                isert \
                knem \
                knem-modules \
                perftest \
                libxpmem \
                libxpmem-devel \
                mlnx-ethtool \
                mlnx-iproute2 \
                mlnx-nfsrdma \
                multiperf \
                srp \
                srp_daemon \
                ucx \
                ucx-cma \
                ucx-devel \
                ucx-ib \
                ucx-ib-mlx5 \
                ucx-rdmacm \
                ucx-static \
                ucx-knem \
                xpmem \
                xpmem-modules \
                ucx-xpmem \
                libunwind \
                libunwind-devel

echo "INSTALLED MOFED!! ${MOFED_VERSION}"
$COMMON_DIR/write_component_version.sh "OFED" $MOFED_VERSION

# Restarting openibd
# /etc/init.d/openibd restart

systemctl enable openibd

# exclude opensm from updates
# sed -i "$ s/$/ opensm*/" /etc/dnf/dnf.conf

# cleanup downloaded files
# rm -rf *.tgz
# rm -rf -- */
