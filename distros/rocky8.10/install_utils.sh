#!/bin/bash
set -ex

source ${UTILS_DIR}/utilities.sh

# Install the "Microsoft TLS RSA Root G2" trust anchor before any HTTPS
# calls to Microsoft endpoints.
$COMPONENT_DIR/install_microsoft_tls_root_g2.sh

# Setup microsoft packages repository for moby
# Download the repository configuration package
curl https://packages.microsoft.com/config/rhel/8/prod.repo > ./microsoft-prod.repo
# Microsoft's moby-runc rpm declares `Provides: runc`, and `runc` is a
# `container-tools` module artifact in AppStream. dnf modular filtering
# would therefore hide every moby-runc-*.el8 rpm and break moby-engine
# install. Mark the MS repo as a hot-fix source to bypass modular
# filtering for its rpms only, without disturbing container-tools.
sed -i '/^\[/a module_hotfixes=1' ./microsoft-prod.repo
# Copy the generated list to the sources.list.d directory
sudo cp ./microsoft-prod.repo /etc/yum.repos.d/

dnf repolist

# Install wget as Rocky Linux 8.10 does not have it by default
sudo dnf install -y wget

# Install net-tools as Rocky Linux 8.10 does not have ifconfig by default
sudo dnf install -y net-tools

# Install jq for JSON parsing (needed by utilities.sh)
sudo dnf install -y jq

# Install Kernel dependencies
KERNEL=$(uname -r)

# Download and install kernel packages using dnf to resolve dependencies
wget --retry-connrefused --tries=3 --waitretry=5 https://dl.rockylinux.org/pub/rocky/8.10/BaseOS/x86_64/os/Packages/k/kernel-devel-${KERNEL}.rpm
wget --retry-connrefused --tries=3 --waitretry=5 https://dl.rockylinux.org/pub/rocky/8.10/BaseOS/x86_64/os/Packages/k/kernel-headers-${KERNEL}.rpm
wget --retry-connrefused --tries=3 --waitretry=5 https://dl.rockylinux.org/pub/rocky/8.10/BaseOS/x86_64/os/Packages/k/kernel-modules-extra-${KERNEL}.rpm || true

# Use dnf localinstall to automatically resolve and install dependencies (e.g., perl-interpreter)
sudo dnf install -y kernel-devel-${KERNEL}.rpm kernel-headers-${KERNEL}.rpm || true
# kernel-modules-extra may not exist for all kernels, so install separately with || true
sudo dnf install -y kernel-modules-extra-${KERNEL}.rpm 2>/dev/null || true

rm -f kernel-devel-${KERNEL}.rpm kernel-headers-${KERNEL}.rpm kernel-modules-extra-${KERNEL}.rpm

# Install EPEL repository
dnf install -y epel-release

# Install pre-reqs and development tools
dnf groupinstall -y "Development Tools"
dnf install -y numactl \
    numactl-devel \
    libxml2-devel \
    byacc \
    bc \
    python3.11-pyyaml \
    gtk2 \
    atk \
    cairo \
    tcl \
    tk \
    m4 \
    glibc-devel \
    libudev-devel \
    binutils \
    binutils-devel \
    selinux-policy-devel \
    nfs-utils \
    fuse-libs \
    libpciaccess \
    cmake \
    libnl3-devel \
    libsecret \
    rpm-build \
    make \
    check \
    check-devel \
    lsof \
    kernel-rpm-macros \
    tcsh \
    gcc-gfortran \
    perl \
    libdrm-devel \
    dos2unix \
    azcopy \
    lvm2

# Install environment-modules 4.5.2
wget https://dl.rockylinux.org/pub/rocky/8.10/BaseOS/x86_64/os/Packages/e/environment-modules-4.5.2-4.el8.x86_64.rpm
dnf install -y environment-modules-4.5.2-4.el8.x86_64.rpm
rm -f environment-modules-4.5.2-4.el8.x86_64.rpm

## Install kernel-abi-stablelists (needed by DOCA) before locking kernel packages
dnf install -y kernel-abi-stablelists

## Disable kernel updates (skipped when refreshing an image in-place so that
## DKMS-style rebuilds can keep up with kernel upgrades, matching the
## Ubuntu prerequisites.sh behavior). The
## shim*/grub2* sed lines extend the just-added exclude= directive, so they
## must stay inside the same conditional -- running them without an exclude
## line would corrupt the previous last line of dnf.conf (e.g.
## skip_if_unavailable=False).
if [[ "${REFRESH_MODE,,}" != "true" ]]; then
    echo "exclude=kernel kernel-core kernel-modules kernel-devel kernel-headers kernel-modules-extra" | tee -a /etc/dnf/dnf.conf
    # Disable dependencies on kernel core
    sed -i "$ s/$/ shim*/" /etc/dnf/dnf.conf
    sed -i "$ s/$/ grub2*/" /etc/dnf/dnf.conf
fi

## Install EPEL packages (pssh, dkms, subunit, subunit-devel)
dnf install -y pssh dkms subunit subunit-devel

echo ib_ipoib | sudo tee /etc/modules-load.d/ib_ipoib.conf

# copy kvp client file
$COMPONENT_DIR/copy_kvp_client.sh

# copy torset tool
$COMPONENT_DIR/copy_torset_tool.sh
