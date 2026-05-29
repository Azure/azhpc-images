#!/bin/bash

set -ex

source ${UTILS_DIR}/utilities.sh

if [[ $DISTRIBUTION == "azurelinux3.0" ]]; then
   kernel_version=$(rpm -q kernel | sed 's/kernel\-//g')
   write_component_version "KERNEL" ${kernel_version::-12}
   os_version=$(rpm -qf /etc/os-release)
   write_component_version "OS" ${os_version::-12}
else
   write_component_version "KERNEL" $(uname -r)
fi
