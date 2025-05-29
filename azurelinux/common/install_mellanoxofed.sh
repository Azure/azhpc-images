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
                https://packages.microsoft.com/azurelinux/3.0/prod/base/x86_64/Packages/m/mlnx-ofa_kernel-24.10-13.azl3.x86_64.rpm \
                https://packages.microsoft.com/azurelinux/3.0/prod/base/x86_64/Packages/m/mlnx-ofa_kernel-modules-24.10-13.azl3.x86_64.rpm \
                https://packages.microsoft.com/azurelinux/3.0/prod/base/x86_64/Packages/m/mlnx-ofa_kernel-devel-24.10-13.azl3.x86_64.rpm \
                https://packages.microsoft.com/azurelinux/3.0/prod/base/x86_64/Packages/m/mlnx-ofa_kernel-source-24.10-13.azl3.x86_64.rpm \
                https://packages.microsoft.com/azurelinux/3.0/prod/base/x86_64/Packages/m/mft_kernel-4.30.0-13.azl3.x86_64.rpm \
                mstflint \
                https://packages.microsoft.com/azurelinux/3.0/prod/base/x86_64/Packages/f/fwctl-24.10-13.azl3.x86_64.rpm  \
                ibacm \
                ibarr \
                ibsim \
                https://packages.microsoft.com/azurelinux/3.0/prod/base/x86_64/Packages/i/iser-24.10-13.azl3.x86_64.rpm \
                https://packages.microsoft.com/azurelinux/3.0/prod/base/x86_64/Packages/i/isert-24.10-13.azl3.x86_64.rpm \
                https://packages.microsoft.com/azurelinux/3.0/prod/base/x86_64/Packages/k/knem-1.1.4.90mlnx3-13.azl3.x86_64.rpm \
                https://packages.microsoft.com/azurelinux/3.0/prod/base/x86_64/Packages/k/knem-modules-1.1.4.90mlnx3-13.azl3.x86_64.rpm \
                perftest \
                libxpmem \
                libxpmem-devel \
                mlnx-ethtool \
                mlnx-iproute2 \
                https://packages.microsoft.com/azurelinux/3.0/prod/base/x86_64/Packages/m/mlnx-nfsrdma-24.10-13.azl3.x86_64.rpm \
                multiperf \
                https://packages.microsoft.com/azurelinux/3.0/prod/base/x86_64/Packages/s/srp-24.10-13.azl3.x86_64.rpm \
                srp_daemon \
                ucx \
                ucx-cma \
                ucx-devel \
                ucx-ib \
                ucx-ib-mlx5 \
                ucx-rdmacm \
                ucx-static \
                ucx-knem \
                https://packages.microsoft.com/azurelinux/3.0/prod/base/x86_64/Packages/x/xpmem-2.7.4-13.azl3.x86_64.rpm \
                https://packages.microsoft.com/azurelinux/3.0/prod/base/x86_64/Packages/x/xpmem-modules-2.7.4-13.azl3.x86_64.rpm \
                ucx-xpmem \
                libunwind \
                libunwind-devel

echo "INSTALLED MOFED!! ${MOFED_VERSION}"
$COMMON_DIR/write_component_version.sh "MOFED" $MOFED_VERSION

# Restarting openibd
# /etc/init.d/openibd restart

systemctl enable openibd

# exclude opensm from updates
# sed -i "$ s/$/ opensm*/" /etc/dnf/dnf.conf

# cleanup downloaded files
# rm -rf *.tgz
# rm -rf -- */
