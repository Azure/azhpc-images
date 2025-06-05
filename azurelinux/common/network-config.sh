#!/bin/bash
set -ex

# sed -i '/\[main\]/a no-auto-default=*' /etc/NetworkManager/NetworkManager.conf

# # update network config on reboot
# mkdir -p /lib/systemd/system/cloud-init-local.service.d/
# cat <<EOF > /lib/systemd/system/cloud-init-local.service.d/50-azure-clear-persistent-obj-pkl.conf
# [Service]
# ExecStartPre=-/bin/sh -xc 'if [ -e /var/lib/cloud/instance/obj.pkl ]; then echo "cleaning persistent cloud-init object"; rm /var/lib/cloud/instance/obj.pkl; fi; exit 0'
# EOF

# Use the domain name received from the DHCP server as DNS search domain
# https://github.com/systemd/systemd/pull/32194
# https://github.com/microsoft/azurelinux/pull/8741
cat << EOF > /etc/systemd/networkd.conf
[Network]
#SpeedMeter=no
#SpeedMeterIntervalSec=10sec
#ManageForeignRoutingPolicyRules=yes
#ManageForeignRoutes=yes
#RouteTable=

[DHCPv4]
#DUIDType=vendor
#DUIDRawData=
UseDomains=yes

[DHCPv6]
#DUIDType=vendor
#DUIDRawData=
UseDomains=yes
EOF

systemctl restart systemd-networkd
systemctl is-active systemd-networkd

# Reset kernel firewall defaults
# Mariner has an iptables systemd service that sets firewalls rules
# from the following files:
# /etc/systemd/scripts/ip4save
# /etc/systemd/scripts/ip6save

# Stop iptables service
systemctl stop iptables
systemctl disable iptables

# Reset defaults
iptables -P INPUT ACCEPT
iptables -P OUTPUT ACCEPT
iptables -P FORWARD ACCEPT