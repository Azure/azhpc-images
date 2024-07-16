#!/bin/bash
set -ex

apt-get install -y walinuxagent

# Configure WALinuxAgent
sed -i -e 's/Provisioning.MonitorHostName=n/Provisioning.MonitorHostName=y/g' /etc/waagent.conf

$COMMON_DIR/install_waagent.sh

systemctl daemon-reload
systemctl restart walinuxagent

$COMMON_DIR/write_component_version.sh "WAAGENT" $(waagent --version | head -n 1 | awk -F' ' '{print $1}' | awk -F- '{print $2}')
$COMMON_DIR/write_component_version.sh "WAAGENT-EXT" $(waagent --version | head -n 3 | awk -F' ' '{print $4}')
