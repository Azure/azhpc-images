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
cp ./microsoft-prod.repo /etc/yum.repos.d/

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

## Install kernel-abi-stablelists (needed by DOCA) before locking kernel packages
yum install -y kernel-abi-stablelists

## Disable kernel updates (skipped when refreshing an image in-place so that
## DKMS-style rebuilds can keep up with kernel upgrades, matching the
## Ubuntu prerequisites.sh behavior). The
## shim*/grub2* sed lines extend the just-added exclude= directive, so they
## must stay inside the same conditional -- running them without an exclude
## line would corrupt the previous last line of dnf.conf (e.g.
## skip_if_unavailable=False).
if [[ "${REFRESH_MODE,,}" != "true" ]]; then
    echo "exclude=kernel*" | tee -a /etc/dnf/dnf.conf
    # Disable dependencies on kernel core
    sed -i "$ s/$/ shim*/" /etc/dnf/dnf.conf
    sed -i "$ s/$/ grub2*/" /etc/dnf/dnf.conf
fi

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
