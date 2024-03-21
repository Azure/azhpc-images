#!/bin/bash
set -ex

# Disable Cloud-Init
cat << EOF >> /etc/cloud/cloud.cfg.d/99-custom-networking.cfg
network: {config: disabled}
EOF

# Remove Hardware Mac Address and DHCP Name
cp /etc/sysconfig/network-scripts/ifcfg-eth0 tempFile
grep -v -E "HWADDR=|DHCP_HOSTNAME=" /etc/sysconfig/network-scripts/ifcfg-eth0 > tempFile
mv tempFile /etc/sysconfig/network-scripts/ifcfg-eth0
