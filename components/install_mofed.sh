#!/bin/bash
set -ex

source ${UTILS_DIR}/utilities.sh

if [[ $DISTRIBUTION == "azurelinux3.0" ]]; then
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
    
    if [ "$ARCHITECTURE" = "aarch64" ]; then
        tdnf install -y mlnx-ofa_kernel \
                    mlnx-ofa_kernel-hwe-modules \
                    mlnx-ofa_kernel-hwe-devel \
                    mlnx-ofa_kernel-source \
                    mft_kernel-hwe \
                    iser-hwe \
                    isert-hwe \
                    knem \
                    knem-hwe-modules \
                    mlnx-nfsrdma-hwe \
                    srp-hwe \
                    xpmem \
                    xpmem-hwe-modules
    else
        tdnf install -y mlnx-ofa_kernel \
                    mlnx-ofa_kernel-modules \
                    mlnx-ofa_kernel-devel \
                    mlnx-ofa_kernel-source \
                    mft_kernel \
                    iser \
                    isert \
                    knem \
                    knem-modules \
                    mlnx-nfsrdma \
                    srp \
                    xpmem \
                    xpmem-modules
    fi     


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
                    mstflint \
                    ibacm \
                    ibarr \
                    ibsim \
                    perftest \
                    libxpmem \
                    libxpmem-devel \
                    mlnx-ethtool \
                    mlnx-iproute2 \
                    multiperf \
                    srp_daemon \
                    ucx \
                    ucx-cma \
                    ucx-devel \
                    ucx-ib \
                    ucx-ib-mlx5 \
                    ucx-rdmacm \
                    ucx-static \
                    ucx-knem \
                    ucx-xpmem \
                    libunwind \
                    libunwind-devel
fi

# Extract mofed version from mlnx-ofa_kernel-devel package
if [ "$ARCHITECTURE" = "aarch64" ]; then
    MOFED_VERSION=$(sudo tdnf list installed | grep mlnx-ofa_kernel-hwe-devel | sed 's/.*\s\+\([0-9.]\+-[0-9]\+\)_.*/\1/')
else
    MOFED_VERSION=$(sudo tdnf list installed | grep mlnx-ofa_kernel-devel | sed 's/.*\s\+\([0-9.]\+-[0-9]\+\)_.*/\1/')
fi
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
write_component_version "OFED" $SOURCE_VERSION

# Create systemd drop-in configuration for openibd.service
# This adds restart on failure and ensures it starts after udev settles
mkdir -p /etc/systemd/system/openibd.service.d
cat > /etc/systemd/system/openibd.service.d/override.conf <<EOF
[Unit]
After=systemd-udev-settle.service
Wants=systemd-udev-settle.service

[Service]
Restart=on-failure
RestartSec=5
EOF

systemctl daemon-reload
systemctl enable openibd
