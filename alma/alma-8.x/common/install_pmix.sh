#!/bin/bash

PMIX_VERSION=4.2.9-1
OS_VERSION=$(cat /etc/os-release  | grep VERSION_ID | cut -d= -f2 | cut -d\" -f2 | cut -d. -f1)
if [ $OS_VERSION == 8 ]; then
   cp slurmel8.repo /etc/yum.repos.d/slurm.repo
   release=el8
elif [ $OS_VERSION == 7 ]; then
   cp slurmel7.repo /etc/yum.repos.d/slurm.repo
   release=el7
else echo "unsupported version"
fi

## This package is pre-installed in all hpc images used by cyclecloud, but if customer wants to
## build an image from generic marketplace images then this package sets up the right gpg keys for PMC.
if [ ! -e /etc/yum.repos.d/microsoft-prod.repo ];then
   curl -sSL -O https://packages.microsoft.com/config/rhel/$OS_VERSION/packages-microsoft-prod.rpm
   rpm -i packages-microsoft-prod.rpm
   rm packages-microsoft-prod.rpm
fi

yum -y install pmix-$PMIX_VERSION.$release