#!/bin/bash
set -ex

PMIX_VERSION=$(jq -r '.pmix."'"$DISTRIBUTION"'".version' <<< $COMPONENT_VERSIONS)

cp slurmel8.repo /etc/yum.repos.d/slurm.repo

## This package is pre-installed in all hpc images used by cyclecloud, but if customer wants to
## build an image from generic marketplace images then this package sets up the right gpg keys for PMC.
if [ ! -e /etc/yum.repos.d/microsoft-prod.repo ];then
   curl -sSL -O https://packages.microsoft.com/config/rhel/8/packages-microsoft-prod.rpm
   rpm -i packages-microsoft-prod.rpm
   rm packages-microsoft-prod.rpm
fi

dnf config-manager --set-enabled powertools
yum -y install pmix-$PMIX_VERSION.el8 hwloc-devel libevent-devel

$COMMON_DIR/write_component_version.sh "PMIX" ${PMIX_VERSION}