#!/bin/bash
set -ex

# Update WALinuxAgent - for IPoIB
tdnf update -y WALinuxAgent

# Configure WALinuxAgent

$COMMON_DIR/install_waagent.sh

systemctl restart waagent
