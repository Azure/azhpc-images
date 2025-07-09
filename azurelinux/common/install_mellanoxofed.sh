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

kernel_version=$(uname -r | sed 's/\-/./g')

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
                mlnx-ofa_kernel-24.10-20_$kernel_version.x86_64 \
                mlnx-ofa_kernel-modules-24.10-20_$kernel_version.x86_64 \
                mlnx-ofa_kernel-devel-24.10-20_$kernel_version.x86_64 \
                mlnx-ofa_kernel-source-24.10-20_$kernel_version.x86_64 \
                mft_kernell-4.30.0-20_$kernel_version.x86_64 \
                mstflint \
                fwctl-24.10-20_$kernel_version.x86_64 \
                ibacm \
                ibarr \
                ibsim \
                iser-24.10-20_$kernel_version.x86_64 \
                isert-24.10-20_$kernel_version.x86_64 \
                knem-1.1.4.90mlnx3-20_$kernel_version.x86_64 \
                knem-modules-1.1.4.90mlnx3-20_$kernel_version.x86_64 \
                perftest \
                libxpmem-2.7.4-20_$kernel_version.x86_64 \
                libxpmem-devel-2.7.4-20_$kernel_version.x86_64 \
                mlnx-ethtool \
                mlnx-iproute2 \
                mlnx-nfsrdma-24.10-20_$kernel_version.x86_64 \
                multiperf \
                srp-24.10-20_$kernel_version.x86_64 \
                srp_daemon \
                ucx \
                ucx-cma \
                ucx-devel \
                ucx-ib \
                ucx-ib-mlx5 \
                ucx-rdmacm \
                ucx-static \
                ucx-knem \
                xpmem-2.7.4-20_$kernel_version.x86_64 \
                xpmem-modules-2.7.4-20_$kernel_version.x86_64 \
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
