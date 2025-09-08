#!/bin/bash
set -ex

source ${UTILS_DIR}/utilities.sh

pmix_metadata=$(get_component_config "pmix")
PMIX_VERSION=$(jq -r '.version' <<< $pmix_metadata)

if [[ $DISTRIBUTION == ubuntu* ]]; then
    UBUNTU_VERSION=$(cat /etc/os-release | grep VERSION_ID | cut -d= -f2 | cut -d\" -f2)
    if [ $UBUNTU_VERSION == 24.04 ]; then
        REPO=slurm-ubuntu-noble
    elif [ $UBUNTU_VERSION == 22.04 ]; then
        REPO=slurm-ubuntu-jammy
    else echo "$DISTRIBUTION not supported for pmix installation."
    fi
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft-prod.gpg] https://packages.microsoft.com/repos/$REPO/ insiders main" > /etc/apt/sources.list.d/slurm.list
    cp ${COMPONENT_DIR}/slurm-repo/slurm-u.pin /etc/apt/preferences.d/slurm-repository-pin-990
    ## This package is pre-installed in all hpc images used by cyclecloud, but if customer wants to
    ## use generic ubuntu marketplace image then this package sets up the right gpg keys for PMC.
    if [ ! -e /etc/apt/sources.list.d/microsoft-prod.list ]; then
        curl -sSL -O https://packages.microsoft.com/config/ubuntu/$UBUNTU_VERSION/packages-microsoft-prod.deb
        dpkg -i packages-microsoft-prod.deb
        rm packages-microsoft-prod.deb
    fi
    apt update
    apt install -y pmix=${PMIX_VERSION} libevent-dev libhwloc-dev # libmunge-dev
    # Hold versions of packages to prevent accidental updates. Packages can still be upgraded explictly by
    # '--allow-change-held-packages' flag.
    apt-mark hold pmix=${PMIX_VERSION} libevent-dev libhwloc-dev # libmunge-dev
elif [[ $DISTRIBUTION == almalinux* ]]; then
    OS_MAJOR_VERSION=$(sed -n 's/^VERSION_ID="\([0-9]\+\).*/\1/p' /etc/os-release)
    cp ${COMPONENT_DIR}/slurm-repo/slurm-el${OS_MAJOR_VERSION}.repo /etc/yum.repos.d/slurm.repo

    if [ ! -e /etc/yum.repos.d/microsoft-prod.repo ];then
        curl -sSL -O https://packages.microsoft.com/config/rhel/${OS_MAJOR_VERSION}/packages-microsoft-prod.rpm
        rpm -i packages-microsoft-prod.rpm
        rm packages-microsoft-prod.rpm
    fi

    if [[ $OS_MAJOR_VERSION == "9" ]]; then 
        dnf config-manager --set-enabled crb
    elif  [[ $OS_MAJOR_VERSION == "8" ]]; then
        dnf config-manager --set-enabled powertools
    fi
    yum update
    yum -y install pmix-${PMIX_VERSION}.el${OS_MAJOR_VERSION} hwloc-devel libevent-devel munge-devel
elif [[ $DISTRIBUTION == "azurelinux3.0" ]]; then
    tdnf -y install pmix-${PMIX_VERSION}.azl3.x86_64 pmix-devel-${PMIX_VERSION}.azl3.x86_64 pmix-tools-${PMIX_VERSION}.azl3.x86_64
    tdnf -y install hwloc-devel libevent-devel munge-devel
else echo "$DISTRIBUTION not supported for pmix installation."
fi

write_component_version "PMIX" ${PMIX_VERSION}
