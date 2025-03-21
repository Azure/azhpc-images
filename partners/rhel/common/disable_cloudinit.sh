#!/bin/bash
set -ex

# Disable Cloud-Init
cat << EOF >> /etc/cloud/cloud.cfg.d/99-custom-networking.cfg
network: {config: disabled}
EOF

# Remove Hardware Mac Address and DHCP Name
sed -i '/^HWADDR=.*$/d' /etc/sysconfig/network-scripts/ifcfg-eth0 
sed -i '/^DHCP_HOSTNAME=.*$/d' /etc/sysconfig/network-scripts/ifcfg-eth0 
sed -i '/^IPV6INIT=.*$/d' /etc/sysconfig/network-scripts/ifcfg-eth0 
