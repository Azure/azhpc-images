#!/bin/bash
set -ex

# Expected params:
# $1 = the major version of the distro. "8" for RHEL/Alma8, "9" for RHEL/Alma9.

DISTRIB_CODENAME="el$1"
repo_path=/etc/yum.repos.d/amlfs.repo

rpm --import https://packages.microsoft.com/keys/microsoft.asc

echo -e "[amlfs]" > $repo_path
echo -e "name=Azure Lustre Packages" >> $repo_path
echo -e "baseurl=https://packages.microsoft.com/yumrepos/amlfs-${DISTRIB_CODENAME}" >> $repo_path
echo -e "enabled=1" >> $repo_path
echo -e "gpgcheck=1" >> $repo_path
echo -e "gpgkey=https://packages.microsoft.com/keys/microsoft.asc" >> $repo_path
