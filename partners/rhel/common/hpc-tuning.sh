#!/bin/bash
set -ex

# Disable some unneeded services by default (administrators can re-enable if desired)
systemctl disable firewalld

# Remove auoms if exists - Prevent CPU utilization by auoms
if yum list installed azsec-monitor >/dev/null 2>&1; then yum remove -y azsec-monitor; fi

$COMMON_DIR/hpc-tuning.sh

# Azure Linux Agent
$RHEL_COMMON_DIR/install_waagent.sh
