#!/bin/bash
set -ex

# Clear History
sudo rm -rf /var/log/*
sudo rm -f /etc/resolv.conf /var/lib/NetworkManager/* /etc/ssh/ssh_host_*
sudo rm -f /tmp/*.log* /tmp/ssh-* /tmp/yum*  /tmp/tmp*
sudo rm -f /var/spool/plymouth/boot.log 
sudo rm -f /var/lib/dhclient/* /var/lib/systemd/random-seed
sudo rm -rf /var/cache/*
unset HISTFILE
#rm -f /root/.bash_history
history -c
sudo rm -rf /run/cloud-init /var/lib/cloud/instances/*
yum clean all

