#!/bin/bash
set -ex

# Install Kernel dependencies
KERNEL=( $(rpm -q kernel | sed 's/kernel\-//g') )
yum install -y https://repo.almalinux.org/vault/8.7/BaseOS/x86_64/os/Packages/kernel-devel-${KERNEL}.rpm \
    https://repo.almalinux.org/vault/8.7/BaseOS/x86_64/os/Packages/kernel-headers-${KERNEL}.rpm \
    https://repo.almalinux.org/vault/8.7/BaseOS/x86_64/os/Packages/kernel-modules-extra-${KERNEL}.rpm

# Install Python 3.8
yum install -y python3.8
ln -fs /usr/bin/python3.8 /usr/bin/python3

# install pssh
pssh_metadata=$(jq -r '.pssh."'"$DISTRIBUTION"'"' <<< $COMPONENT_VERSIONS)
PSSH_VERSION=$(jq -r '.version' <<< $pssh_metadata)
PSSH_SHA256=$(jq -r '.sha256' <<< $pssh_metadata)
pssh_download_url="https://dl.fedoraproject.org/pub/epel/8/Everything/aarch64/Packages/p/pssh-$PSSH_VERSION.el8.noarch.rpm"
$COMMON_DIR/download_and_verify.sh $pssh_download_url $PSSH_SHA256

yum install -y  pssh-$PSSH_VERSION.el8.noarch.rpm
rm -f pssh-$PSSH_VERSION.el8.noarch.rpm

# Install pre-reqs and development tools
yum groupinstall -y "Development Tools"
yum install -y numactl \
    numactl-devel \
    libxml2-devel \
    byacc \
    environment-modules \
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
    perl

## Disable kernel updates
echo "exclude=kernel* kmod*" | tee -a /etc/dnf/dnf.conf

# Disable dependencies on kernel core
sed -i "$ s/$/ shim*/" /etc/dnf/dnf.conf
sed -i "$ s/$/ grub2*/" /etc/dnf/dnf.conf

## Install dkms from the EPEL repository
wget -r --no-parent -A "dkms-*.el8.noarch.rpm" https://dl.fedoraproject.org/pub/epel/8/Everything/x86_64/Packages/d/
yum localinstall ./dl.fedoraproject.org/pub/epel/8/Everything/x86_64/Packages/d/dkms-*.el8.noarch.rpm -y

## Install subunit and subunit-devel from EPEL repository
wget -r --no-parent -A "subunit-*.el8.x86_64.rpm" https://dl.fedoraproject.org/pub/epel/8/Everything/x86_64/Packages/s/
yum localinstall ./dl.fedoraproject.org/pub/epel/8/Everything/x86_64/Packages/s/subunit-[0-9].*.el8.x86_64.rpm -y
yum localinstall ./dl.fedoraproject.org/pub/epel/8/Everything/x86_64/Packages/s/subunit-devel-[0-9].*.el8.x86_64.rpm -y

# Download jq utility
wget -r --no-parent -A "jq-*.el8.x86_64.rpm" https://repo.almalinux.org/almalinux/8/AppStream/x86_64/os/Packages/
yum localinstall ./repo.almalinux.org/almalinux/8/AppStream/x86_64/os/Packages/jq-*.el8.x86_64.rpm -y

# Remove rpm files
rm -rf ./dl.fedoraproject.org/
rm -rf ./repo.almalinux.org/

# Install azcopy tool
# To copy blobs or files to or from a storage account
azcopy_metadata=$(jq -r '.azcopy."'"$DISTRIBUTION"'"' <<< $COMPONENT_VERSIONS)
azcopy_version=$(jq -r '.version' <<< $azcopy_metadata)
azcopy_release=$(jq -r '.release' <<< $azcopy_metadata)
azcopy_sha256=$(jq -r '.sha256' <<< $azcopy_metadata)
TARBALL="azcopy_linux_amd64_$azcopy_version.tar.gz"
AZCOPY_DOWNLOAD_URL="https://azcopyvnext.azureedge.net/$azcopy_release/$TARBALL"
wget ${AZCOPY_DOWNLOAD_URL}
tar -xvf ${TARBALL}

# copy the azcopy to the bin path
pushd azcopy_linux_amd64_${VERSION}
cp azcopy /usr/bin/
popd

# Allow execute permissions
chmod +x /usr/bin/azcopy

# remove tarball from azcopy
rm -rf *.tar.gz

# copy kvp client file
$COMMON_DIR/copy_kvp_client.sh
