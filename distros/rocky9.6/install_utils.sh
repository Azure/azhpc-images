#!/bin/bash
set -ex

source ${UTILS_DIR}/utilities.sh

# Setup microsoft packages repository for moby
# Download the repository configuration package
curl https://packages.microsoft.com/config/rhel/9/prod.repo > ./microsoft-prod.repo
# Copy the generated list to the sources.list.d directory
sudo cp ./microsoft-prod.repo /etc/yum.repos.d/

dnf repolist

# Install wget, net-tools, python3.12, and jq early (needed for kernel downloads and utilities)
sudo dnf install -y wget \
               net-tools \
               python3.12 \
               jq

# Install Kernel dependencies
# Rocky 9.6 kernel-devel installation requires complex fallback logic due to:
# 1. kernel-devel-matched may not always find exact match in active repositories
# 2. Azure VMs may run on kernel versions only available in vault mirrors
# 3. kernel-devel must exactly match running kernel for DKMS module builds (DOCA, ROCm drivers)
# 4. Dependency resolution requires dnf (not raw rpm) to handle perl-interpreter and other deps
#
# Strategy:
# - Try kernel-devel-matched first (best case - handles version matching automatically)
# - Fall back to vault mirror if exact match not found in standard repos
# - Fix symlinks if kernel-devel directory doesn't match expected path
# - Always use 'dnf install' for proper dependency resolution per repository policy
KERNEL=$(uname -r)
sudo dnf install -y kernel-devel-matched kernel-headers kernel-modules-extra --disableexcludes=main || true

# Check if exact kernel-devel for running kernel exists, if not try fallback mirror
if [ ! -d "/usr/src/kernels/${KERNEL//.x86_64/}.x86_64" ]; then
    echo "Exact kernel-devel not found in standard repos, trying Rocky vault mirror..."
    KERNEL_VERSION_SHORT=$(echo $KERNEL | sed 's/.el9_6.x86_64//')
    FALLBACK_URL="https://mirror.cse.umn.edu/rocky-vault/9.6/AppStream/x86_64/kickstart/Packages/k/kernel-devel-${KERNEL}.rpm"
    wget -q "$FALLBACK_URL" || echo "Warning: Could not download from fallback mirror"
    if [ -f "kernel-devel-${KERNEL}.rpm" ]; then
        # Use dnf to automatically resolve dependencies like perl-interpreter
        sudo dnf install -y "kernel-devel-${KERNEL}.rpm"
        rm -f "kernel-devel-${KERNEL}.rpm"
    fi
fi

# Fix kernel-devel symlinks if needed
if [ ! -e "/lib/modules/${KERNEL}/build" ] || [ ! -d "$(readlink -f /lib/modules/${KERNEL}/build 2>/dev/null)" ]; then
    # Prefer exact matching kernel-devel
    if [ -d "/usr/src/kernels/${KERNEL//.x86_64/}.x86_64" ]; then
        KERNEL_DEVEL_DIR="/usr/src/kernels/${KERNEL//.x86_64/}.x86_64"
    else
        # Fall back to any available kernel-devel
        KERNEL_DEVEL_DIR=$(ls -1d /usr/src/kernels/*.x86_64 2>/dev/null | head -1)
    fi

    if [ -n "$KERNEL_DEVEL_DIR" ] && [ -d "$KERNEL_DEVEL_DIR" ]; then
        echo "Fixing kernel build symlinks to point to: $KERNEL_DEVEL_DIR"
        sudo rm -f /lib/modules/${KERNEL}/build
        sudo rm -f /lib/modules/${KERNEL}/source
        sudo ln -s "$KERNEL_DEVEL_DIR" /lib/modules/${KERNEL}/build
        sudo ln -s "$KERNEL_DEVEL_DIR" /lib/modules/${KERNEL}/source
    fi
fi

sudo alternatives --install /usr/bin/python3 python3 /usr/bin/python3.9 20
sudo alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 10
sudo alternatives --set python3 /usr/bin/python3.9

# install pssh
pssh_metadata=$(get_component_config "pssh")
pssh_version=$(jq -r '.version' <<< $pssh_metadata)
pssh_sha256=$(jq -r '.sha256' <<< $pssh_metadata)
pssh_download_url="https://dl.fedoraproject.org/pub/epel/9/Everything/x86_64/Packages/p/pssh-$pssh_version.el9.noarch.rpm"
download_and_verify $pssh_download_url $pssh_sha256

dnf install -y  pssh-$pssh_version.el9.noarch.rpm
rm -f pssh-$pssh_version.el9.noarch.rpm

# Enable CRB (CodeReady Builder) repository for Rocky 9
# Required for CycleCloud Slurm installer compatibility (Rocky 8 uses 'powertools', Rocky 9 uses 'crb')
dnf config-manager --set-enabled crb

# Create 'powertools' alias for CRB repository to support CycleCloud Slurm installer
# CycleCloud's installer is hardcoded for Rocky 8 and tries to enable 'powertools'
# This alias allows that command to succeed without modification to CycleCloud
cat > /etc/yum.repos.d/powertools.repo <<'EOF'
[powertools]
name=Rocky Linux $releasever - PowerTools (CRB alias)
mirrorlist=https://mirrors.rockylinux.org/mirrorlist?arch=$basearch&repo=CRB-$releasever
#baseurl=http://dl.rockylinux.org/$contentdir/$releasever/CRB/$basearch/os/
gpgcheck=1
enabled=1
countme=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-Rocky-9
EOF

# Install pre-reqs and development tools
dnf groupinstall -y "Development Tools"
dnf install -y numactl \
    numactl-devel \
    libxml2-devel \
    byacc \
    bc \
    python3-devel \
    python3-setuptools \
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

# Install environment-modules 5.3.0
wget https://dl.rockylinux.org/vault/rocky/9.6/BaseOS/x86_64/os/Packages/e/environment-modules-5.3.0-1.el9.x86_64.rpm
dnf install -y environment-modules-5.3.0-1.el9.x86_64.rpm
rm -f environment-modules-5.3.0-1.el9.x86_64.rpm

## Disable kernel updates (but not kernel-rpm-macros and other tools)
echo "exclude=kernel kernel-core kernel-modules kernel-devel kernel-headers kernel-modules-extra" | tee -a /etc/dnf/dnf.conf

# Disable dependencies on kernel core
sed -i "$ s/$/ shim*/" /etc/dnf/dnf.conf
sed -i "$ s/$/ grub2*/" /etc/dnf/dnf.conf

## Install dkms from the EPEL repository
wget -r --no-parent -A "dkms-*.el9.noarch.rpm" https://dl.fedoraproject.org/pub/epel/9/Everything/x86_64/Packages/d/
dnf localinstall ./dl.fedoraproject.org/pub/epel/9/Everything/x86_64/Packages/d/dkms-*.el9.noarch.rpm -y

## Install subunit and subunit-devel from EPEL repository
wget -r --no-parent -A "subunit-*.el9.x86_64.rpm" https://dl.fedoraproject.org/pub/epel/9/Everything/x86_64/Packages/s/
dnf localinstall ./dl.fedoraproject.org/pub/epel/9/Everything/x86_64/Packages/s/subunit-[0-9].*.el9.x86_64.rpm -y
dnf localinstall ./dl.fedoraproject.org/pub/epel/9/Everything/x86_64/Packages/s/subunit-devel-[0-9].*.el9.x86_64.rpm -y

# Remove rpm files
rm -rf ./dl.fedoraproject.org/
rm -rf ./dl.rockylinux.org/

echo ib_ipoib | sudo tee /etc/modules-load.d/ib_ipoib.conf

# copy kvp client file
$COMPONENT_DIR/copy_kvp_client.sh

# copy torset tool
$COMPONENT_DIR/copy_torset_tool.sh
