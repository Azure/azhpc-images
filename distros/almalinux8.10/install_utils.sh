#!/bin/bash
set -ex

source ${UTILS_DIR}/utilities.sh

# Install the "Microsoft TLS RSA Root G2" trust anchor before any HTTPS
# calls to Microsoft endpoints.
$COMPONENT_DIR/install_microsoft_tls_root_g2.sh

# Setup Microsoft package repositories. Alma uses the native Alma repo, while
# Moby packages currently come from the RHEL repo under a distinct repo ID.
curl https://packages.microsoft.com/config/alma/8/prod.repo > ./microsoft-prod.repo
sed -i '/^\[/a priority=10' ./microsoft-prod.repo
sed -i '/^\[/a module_hotfixes=1' ./microsoft-prod.repo
curl https://packages.microsoft.com/config/rhel/8/prod.repo > ./microsoft-rhel-prod.repo
sed -i 's/^\[packages-microsoft-com-prod\]/[packages-microsoft-com-rhel-prod]/' ./microsoft-rhel-prod.repo
sed -i 's/^name=Microsoft Production/name=Microsoft RHEL Production/' ./microsoft-rhel-prod.repo
sed -i '/^\[/a priority=20' ./microsoft-rhel-prod.repo
# Microsoft's moby-runc rpm declares `Provides: runc`, and `runc` is a
# `container-tools` module artifact in AppStream. dnf modular filtering
# would therefore hide every moby-runc-*.el8 rpm and break moby-engine
# install. Mark the RHEL MS repo as a hot-fix source to bypass modular
# filtering for its rpms only, without disturbing container-tools.
sed -i '/^\[/a module_hotfixes=1' ./microsoft-rhel-prod.repo
# Copy the generated list to the sources.list.d directory
grep -lE '^\[(packages-microsoft-com-prod|packages-microsoft-com-rhel-prod)\]' /etc/yum.repos.d/*.repo 2>/dev/null | xargs -r rm -f
cp ./microsoft-prod.repo /etc/yum.repos.d/
cp ./microsoft-rhel-prod.repo /etc/yum.repos.d/

yum repolist

# Install Kernel dependencies
KERNEL=( $(rpm -q kernel | sed 's/kernel\-//g') )

yum install -y https://repo.almalinux.org/almalinux/8.10/BaseOS/x86_64/os/Packages/kernel-devel-${KERNEL}.rpm \
    https://repo.almalinux.org/almalinux/8.10/BaseOS/x86_64/os/Packages/kernel-headers-${KERNEL}.rpm \
    https://repo.almalinux.org/almalinux/8.10/BaseOS/x86_64/os/Packages/kernel-modules-extra-${KERNEL}.rpm

# Install wget as AlmaLinux 8.10 does not have it by default
sudo yum install -y wget

# Install net-tools as AlmaLinux 8.10 does not have ifconfig by default
sudo yum install -y net-tools

sudo yum install -y python3.12
alternatives --install /usr/bin/python3 python3 /usr/bin/python3.6 20
alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 10
alternatives --set python3 /usr/bin/python3.6

# Install EPEL repository
yum install -y epel-release

dnf -y install dnf-plugins-core
dnf config-manager --set-enabled powertools

# Install pre-reqs and development tools
yum groupinstall -y "Development Tools"
yum install -y numactl \
    numactl-devel \
    libxml2-devel \
    byacc \
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
    json-c-devel \
    dos2unix \
    azcopy \
    mdadm

# Install environment-modules 5.0.1
wget https://repo.almalinux.org/vault/9.1/BaseOS/x86_64/os/Packages/environment-modules-5.0.1-1.el9.x86_64.rpm
yum install -y environment-modules-5.0.1-1.el9.x86_64.rpm
rm -f environment-modules-5.0.1-1.el9.x86_64.rpm

## Install kernel-abi-stablelists (needed by DOCA)
yum install -y kernel-abi-stablelists

## Install EPEL packages (pssh, dkms, subunit, subunit-devel)
yum install -y pssh dkms subunit subunit-devel

# Install azure-vm-utils from source (no upstream package available for AL8)
git clone --depth 1 https://github.com/Azure/azure-vm-utils.git /tmp/azure-vm-utils
pushd /tmp/azure-vm-utils
mkdir build && cd build
cmake -DENABLE_TESTS=0 ..
make
make install
popd
rm -rf /tmp/azure-vm-utils

# copy kvp client file
$COMPONENT_DIR/copy_kvp_client.sh

# copy torset tool
$COMPONENT_DIR/copy_torset_tool.sh
