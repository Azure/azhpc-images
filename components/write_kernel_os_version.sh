#!/bin/bash

set -ex

source ${UTILS_DIR}/utilities.sh

if [[ $DISTRIBUTION == "azurelinux3.0" ]]; then
   write_component_version "KERNEL" $(uname -r)
   os_version=$(rpm -qf /etc/os-release)
   write_component_version "OS" ${os_version::-12}
else
   write_component_version "KERNEL" $(uname -r)
fi
