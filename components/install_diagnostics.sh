#!/bin/bash
set -ex

DESTINATION_DIR=/opt/azurehpc/diagnostics

install_package() {
    if [[ $DISTRIBUTION == *"ubuntu"* ]]; then
        apt-get install -y "$1"
    else
        dnf install -y "$2"
    fi
}

# The script runs through a pkexec shebang; pkexec isn't installed on every distro
# (e.g. Azure Linux 3.0).
command -v pkexec > /dev/null || install_package pkexec polkit
# Used by the collector and by nvidia-bug-report.sh; missing on Azure Linux 3.0
command -v dmidecode > /dev/null || install_package dmidecode dmidecode

mkdir -p $DESTINATION_DIR/schema
install -m 755 $COMPONENT_DIR/diagnostics/azhpc-diagnostics.sh $DESTINATION_DIR/azhpc-diagnostics.sh
install -m 755 $COMPONENT_DIR/diagnostics/azhpc-diagnostics-analyze.sh $DESTINATION_DIR/azhpc-diagnostics-analyze.sh
install -m 644 $COMPONENT_DIR/diagnostics/azhpc-collect-lib.sh $DESTINATION_DIR/azhpc-collect-lib.sh
install -m 644 $COMPONENT_DIR/diagnostics/schema/*.schema.json $DESTINATION_DIR/schema/

# /usr/sbin is in sudo's secure_path on all supported distros
ln -sf $DESTINATION_DIR/azhpc-diagnostics.sh /usr/sbin/azhpc-diagnostics
