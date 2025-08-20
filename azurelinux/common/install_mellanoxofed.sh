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
XPMEM_VERSION=$(jq -r '."xpmem.version"' <<< $mofed_metadata)
KNEM_VERSION=$(jq -r '."knem.version"' <<< $mofed_metadata)
MFT_KERNEL_VERSION=$(jq -r '."mft_kernel.version"' <<< $mofed_metadata)

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
                mlnx-ofa_kernel-${MOFED_VERSION}_$kernel_version.x86_64 \
                mlnx-ofa_kernel-modules-${MOFED_VERSION}_$kernel_version.x86_64 \
                mlnx-ofa_kernel-devel-${MOFED_VERSION}_$kernel_version.x86_64 \
                mlnx-ofa_kernel-source-${MOFED_VERSION}_$kernel_version.x86_64 \
                mft_kernel-${MFT_KERNEL_VERSION}_$kernel_version.x86_64 \
                mstflint \
                fwctl-${MOFED_VERSION}_$kernel_version.x86_64 \
                ibacm \
                ibarr \
                ibsim \
                iser-${MOFED_VERSION}_$kernel_version.x86_64 \
                isert-${MOFED_VERSION}_$kernel_version.x86_64 \
                knem-${KNEM_VERSION}_$kernel_version.x86_64 \
                knem-modules-${KNEM_VERSION}_$kernel_version.x86_64 \
                perftest \
                libxpmem-${XPMEM_VERSION}_$kernel_version.x86_64 \
                libxpmem-devel-${XPMEM_VERSION}_$kernel_version.x86_64 \
                mlnx-ethtool \
                mlnx-iproute2 \
                mlnx-nfsrdma-${MOFED_VERSION}_$kernel_version.x86_64 \
                multiperf \
                srp-${MOFED_VERSION}_$kernel_version.x86_64 \
                srp_daemon \
                ucx \
                ucx-cma \
                ucx-devel \
                ucx-ib \
                ucx-ib-mlx5 \
                ucx-rdmacm \
                ucx-static \
                ucx-knem \
                xpmem-${XPMEM_VERSION}_$kernel_version.x86_64 \
                xpmem-modules-${XPMEM_VERSION}_$kernel_version.x86_64 \
                ucx-xpmem \
                libunwind \
                libunwind-devel

SOURCE_VERSION=$(ofed_info | sed -n '1,1p' | awk -F'-' 'OFS="-" {print $3,$4}' | tr -d ':')

# MOFED_VERSION refers to the RPM package version used in tdnf install.
#   - Example: "24.10-20"
#   - Breakdown:
#       * 24.10  -> OFED major version series
#       * 20     -> RPM package release number (defined by the packager)
#
# SOURCE_VERSION refers to the upstream Mellanox source version, as reported by ofed_info.
#   - Example: "0.7.0"
#
echo "INSTALLED MOFED!! Release Version: ${MOFED_VERSION}, Source Version: ${SOURCE_VERSION}"

# Sanity check consumes the source package version printed by ofed_info. 
# Therefore, though we use release version in versions.json for tdnf install, we need to write the SOURCE_VERSION to the component version file.
$COMMON_DIR/write_component_version.sh "OFED" $SOURCE_VERSION

# Restarting openibd
# /etc/init.d/openibd restart

systemctl enable openibd

# exclude opensm from updates
# sed -i "$ s/$/ opensm*/" /etc/dnf/dnf.conf

# cleanup downloaded files
# rm -rf *.tgz
# rm -rf -- */
