#!/bin/bash
set -ex

# Set Lustre driver version
LUSTRE_VERSION=$(jq -r '.lustre."'"$DISTRIBUTION"'".version' <<< $COMPONENT_VERSIONS)

DISTRIB_CODENAME=el8
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
