#!/bin/bash
set -ex

# Update WALinuxAgent - for IPoIB
yum update -y WALinuxAgent

# Configure WALinuxAgent

$COMMON_DIR/install_waagent.sh

systemctl restart waagent

$COMMON_DIR/write_component_version.sh "WAAGENT" $(waagent --version | head -n 1 | awk -F' ' '{print $1}' | awk -F- '{print $2}')
$COMMON_DIR/write_component_version.sh "WAAGENT_EXTENSIONS" $(waagent --version | sed '3q;d' | awk -F' ' '{print $4}')