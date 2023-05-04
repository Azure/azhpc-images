#!/bin/bash
set -ex

DISTRIB_CODENAME=el8
LUSTRE_VERSION=2.15.1_24_g98d1cac
REPO_PATH=/etc/yum.repos.d/amlfs.repo

rpm --import https://packages.microsoft.com/keys/microsoft.asc

echo -e "[amlfs]" > ${REPO_PATH}
echo -e "name=Azure Lustre Packages" >> ${REPO_PATH}
echo -e "baseurl=https://packages.microsoft.com/yumrepos/amlfs-${DISTRIB_CODENAME}" >> ${REPO_PATH}
echo -e "enabled=1" >> ${REPO_PATH}
echo -e "gpgcheck=1" >> ${REPO_PATH}
echo -e "gpgkey=https://packages.microsoft.com/keys/microsoft.asc" >> ${REPO_PATH}
echo -e "exclude=lustre-client-dkms*" >> ${REPO_PATH}

dnf install -y kmod-lustre-client-$(uname -r)-${LUSTRE_VERSION}-1.${DISTRIB_CODENAME}.x86_64.rpm lustre-client-${LUSTRE_VERSION}-1.${DISTRIB_CODENAME}.x86_64.rpm

$COMMON_DIR/write_component_version.sh "LUSTRE" ${LUSTRE_VERSION}
