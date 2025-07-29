#!/bin/bash
set -ex

export TOP_DIR="$(dirname "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)")"
export COMPONENT_DIR=$TOP_DIR/components
export TEST_DIR=$TOP_DIR/tests
export UTILS_DIR=$TOP_DIR/utils
export DISTRO_FAMILY=$(. /etc/os-release;echo $ID)
export DISTRIBUTION=$(. /etc/os-release;echo $ID$VERSION_ID)

if [[ $DISTRO_FAMILY == "ubuntu" ]]; then
    # Don't allow the kernel to be updated
    apt-mark hold linux-azure
    # upgrade pre-installed components
    apt update
    apt upgrade -y
    # jq is needed to parse the component versions from the versions.json file
    apt install -y jq
    export MODULE_FILES_DIRECTORY=/usr/share/modules/modulefiles
elif [[ $DISTRIBUTION == "almalinux8.10" ]]; then
    # Import the newest AlmaLinux 8 GPG key
    rpm --import https://repo.almalinux.org/almalinux/RPM-GPG-KEY-AlmaLinux
    yum install -y jq    
    export MODULE_FILES_DIRECTORY=/usr/share/Modules/modulefiles
elif [[ $DISTRIBUTION == "azurelinux3.0" ]]; then
    tdnf install -y jq
    export MODULE_FILES_DIRECTORY=/usr/share/Modules/modulefiles
fi

# Component Versions
export COMPONENT_VERSIONS=$(jq -r . $TOP_DIR/versions.json)
