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
# MOFED_SHA256=$(jq -r '.sha256' <<< $mofed_metadata)
# TARBALL="MLNX_OFED_SRC-$MOFED_VERSION.tgz"
# MOFED_DOWNLOAD_URL=https://www.mellanox.com/downloads/ofed/MLNX_OFED-$MOFED_VERSION/$TARBALL
# MOFED_FOLDER=$(basename $MOFED_DOWNLOAD_URL .tgz)
# kernel_without_arch="${KERNEL%.*}"

# $COMMON_DIR/download_and_verify.sh $MOFED_DOWNLOAD_URL $MOFED_SHA256
# tar zxvf $TARBALL

# pushd $MOFED_FOLDER
# ./install.pl --all --without-openmpi
# popd

#Install MOFED and its dependencies from PMC
# tdnf install -y libibumad \
#                 infiniband-diags \
#                 libibverbs \
#                 libibverbs-utils \
#                 ofed-scripts \
#                 mlnx-tools \
#                 librdmacm \
#                 librdmacm-utils \
#                 rdma-core \
#                 rdma-core-devel \
#                 mlnx-ofa_kernel \
#                 mlnx-ofa_kernel-modules \
#                 mlnx-ofa_kernel-devel \
#                 mlnx-ofa_kernel-source \
#                 mft_kernel \
#                 mstflint \
#                 fwctl  \
#                 ibacm \
#                 ibarr \
#                 ibsim \
#                 iser \
#                 isert\
#                 knem \
#                 knem-modules \
#                 perftest \
#                 libxpmem\
#                 libxpmem-devel \
#                 mlnx-ethtool \
#                 mlnx-iproute2 \
#                 mlnx-nfsrdma \
#                 multiperf \
#                 srp  \
#                 srp_daemon \
#                 ucx \
#                 ucx-cma \
#                 ucx-devel \
#                 ucx-ib \
#                 ucx-ib-mlx5 \
#                 ucx-rdmacm \
#                 ucx-static \
#                 ucx-knem \
#                 xpmem \
#                 xpmem-modules \
#                 ucx-xpmem

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
