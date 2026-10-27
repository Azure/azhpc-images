#!/bin/bash
set -e

sed -i 's/APT::Periodic::Unattended-Upgrade ".*/APT::Periodic::Unattended-Upgrade "0";/' /etc/apt/apt.conf.d/20auto-upgrades

systemctl stop unattended-upgrades.service
systemctl disable unattended-upgrades.service
systemctl mask unattended-upgrades.service
