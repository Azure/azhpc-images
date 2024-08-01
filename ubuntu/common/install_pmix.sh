#!/bin/bash
set -ex

source ${COMMON_DIR}/utilities.sh

pmix_metadata=$(get_component_config "pmix")
PMIX_VERSION=$(jq -r '.version' <<< $pmix_metadata)
UBUNTU_VERSION=$(cat /etc/os-release | grep VERSION_ID | cut -d= -f2 | cut -d\" -f2)

if [ $UBUNTU_VERSION == 22.04 ]; then
    REPO=slurm-ubuntu-jammy
elif [ $UBUNTU_VERSION == 20.04 ]; then
    REPO=slurm-ubuntu-focal
else echo "$UBUNTU_VERSION not supported for pmix installation."
fi

echo "deb [arch=amd64] https://packages.microsoft.com/repos/$REPO/ insiders main" > /etc/apt/sources.list.d/slurm.list

# Set priority for pmix and slurm packages from PMC to be higher than upstream ubuntu.
echo "\
Package: slurm-smd*
Pin:  origin \"packages.microsoft.com\"
Pin-Priority: 990

Package: pmix
Pin: origin \"packages.microsoft.com\"
Pin-Priority: 990

Package: slurm*
Pin: origin *ubuntu.com*
Pin-Priority: -1

Package: pmix
Pin: origin *ubuntu.com*
Pin-Priority: -1" > /etc/apt/preferences.d/slurm-repository-pin-990

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

$COMMON_DIR/write_component_version.sh "PMIX" ${PMIX_VERSION}
