#!/bin/bash
set -ex

# Install DCGM
# actual version is 3.0.4, older are in the repo too
# DCGM_VERSION=3.0.4

zypper install -y -l datacenter-gpu-manager
DCGM_VERSION=$(rpm -q  --qf="%{VERSION}" datacenter-gpu-manager)

systemctl --now enable nvidia-dcgm

# to verify the installation we can query the system
# You should see a listing of all supported GPUs (and any NVSwitches) found in the system:
# dcgmi discovery -l

$COMMON_DIR/write_component_version.sh "DCGM" ${DCGM_VERSION}
