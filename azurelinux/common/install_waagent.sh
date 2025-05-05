#!/bin/bash
set -ex

# Update WALinuxAgent - for IPoIB
tdnf update -y WALinuxAgent

# Configure WALinuxAgent

$COMMON_DIR/install_waagent.sh

systemctl restart waagent
waagent_version=$(waagent --version | head -n 1 | awk -F' ' '{print $1}' | awk -F- '{print $2}')
waagent_extensions_version=$(waagent --version | tail -n1 | awk '{print $4}')
$COMMON_DIR/write_component_version.sh "WAAGENT" ${waagent_version}
$COMMON_DIR/write_component_version.sh "WAAGENT_EXTENSIONS" ${waagent_extensions_version}