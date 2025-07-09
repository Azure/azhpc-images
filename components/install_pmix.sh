#!/bin/bash
set -ex

source ${UTILS_DIR}/utilities.sh

pmix_metadata=$(get_component_config "pmix")
PMIX_VERSION=$(jq -r '.version' <<< $pmix_metadata)

if [[ $DISTRIBUTION == "ubuntu22.04" ]]; then
    REPO=slurm-ubuntu-jammy
    echo "deb [arch=amd64] https://packages.microsoft.com/repos/$REPO/ insiders main" > /etc/apt/sources.list.d/slurm.list
    cp ${COMPONENT_DIR}/slurm-repo/slurmu22.pin /etc/apt/preferences.d/slurm-repository-pin-990
    ## This package is pre-installed in all hpc images used by cyclecloud, but if customer wants to
    ## use generic ubuntu marketplace image then this package sets up the right gpg keys for PMC.
    if [ ! -e /etc/apt/sources.list.d/microsoft-prod.list ]; then
        curl -sSL -O https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb
        dpkg -i packages-microsoft-prod.deb
        rm packages-microsoft-prod.deb
    fi
    apt update
    apt install -y pmix=${PMIX_VERSION} libevent-dev libhwloc-dev # libmunge-dev
    # Hold versions of packages to prevent accidental updates. Packages can still be upgraded explictly by
    # '--allow-change-held-packages' flag.
    apt-mark hold pmix=${PMIX_VERSION} libevent-dev libhwloc-dev # libmunge-dev
elif [[ $DISTRIBUTION == "almalinux8.10" ]]; then
    cp ${COMPONENT_DIR}/slurm-repo/slurmel8.repo /etc/yum.repos.d/slurm.repo

    if [ ! -e /etc/yum.repos.d/microsoft-prod.repo ];then
        curl -sSL -O https://packages.microsoft.com/config/rhel/8/packages-microsoft-prod.rpm
        rpm -i packages-microsoft-prod.rpm
        rm packages-microsoft-prod.rpm
    fi

    dnf config-manager --set-enabled powertools
    yum -y install pmix-${PMIX_VERSION}.el8 hwloc-devel libevent-devel munge-devel
elif [[ $DISTRIBUTION == "azurelinux3.0" ]]; then
    tdnf -y install pmix pmix-devel pmix-tools
    tdnf -y install hwloc-devel libevent-devel munge-devel
else echo "$DISTRIBUTION not supported for pmix installation."
fi

write_component_version "PMIX" ${PMIX_VERSION}
