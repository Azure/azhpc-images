#!/bin/bash
set -ex

$COMMON_DIR/install_waagent.sh

# Configure WALinuxAgent
sed -i -e 's/Provisioning.MonitorHostName=n/Provisioning.MonitorHostName=y/g' /etc/waagent.conf

systemctl daemon-reload
systemctl restart walinuxagent
