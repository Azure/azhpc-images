#!/bin/bash
set -ex

# Setup microsoft packages repository for moby
# Download the repository configuration package
curl https://packages.microsoft.com/config/rhel/8/prod.repo > ./microsoft-prod.repo
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

$ALMA_COMMON_DIR/install_utils.sh
