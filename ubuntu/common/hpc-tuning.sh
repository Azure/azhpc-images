#!/bin/bash
set -ex

# Install Dependencies
pip3 install -U netifaces
pip3 install -U PyYAML

# Disable some unneeded services by default (administrators can re-enable if desired)
systemctl disable ufw

$COMMON_DIR/hpc-tuning.sh

# Azure Linux Agent
$UBUNTU_COMMON_DIR/install_waagent.sh
