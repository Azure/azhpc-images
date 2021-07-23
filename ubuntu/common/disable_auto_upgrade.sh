#!/bin/bash
set -e

KERNEL_VERSION=$(uname -r) su -c 'echo linux-image-$KERNEL_VERSION hold | dpkg --set-selections'
sed -i 's/APT::Periodic::Unattended-Upgrade ".*/APT::Periodic::Unattended-Upgrade "0";/' /etc/apt/apt.conf.d/20auto-upgrades

# Holding on the auto updates for nvidia fabric manager and cuda drivers
apt-mark hold nvidia-fabricmanager-* cuda-drivers-fabricmanager-*
