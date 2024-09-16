#!/bin/bash
set -ex

# TEMP add to fix changed behavior in AlmaLinux 8.7
os=$(cat /etc/os-release | awk 'match($0, /^NAME="(.*)"/, result) { print result[1] }')
if [[ $os == "AlmaLinux" ]]
then
    # Remove Hardware Mac Address and DHCP Name
    sed -i '/^HWADDR=.*$/d' /etc/sysconfig/network-scripts/ifcfg-eth0 
    sed -i '/^DHCP_HOSTNAME=.*$/d' /etc/sysconfig/network-scripts/ifcfg-eth0 
fi
