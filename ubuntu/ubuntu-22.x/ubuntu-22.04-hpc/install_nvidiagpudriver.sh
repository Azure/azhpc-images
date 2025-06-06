#!/bin/bash
set -ex

# Dependency for nvidia driver installation
apt-get install -y libvulkan1

$UBUNTU_COMMON_DIR/install_nvidiagpudriver.sh $1
