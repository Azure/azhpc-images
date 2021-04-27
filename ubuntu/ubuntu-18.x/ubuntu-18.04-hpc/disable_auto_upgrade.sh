#!/bin/bash
set -e

su -c 'echo linux-image-5.4.0-1043-azure hold | dpkg --set-selections'
sed -i 's/APT::Periodic::Unattended-Upgrade ".*/APT::Periodic::Unattended-Upgrade "0";/' /etc/apt/apt.conf.d/20auto-upgrades
