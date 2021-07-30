#!/bin/bash
set -ex

# Clear History
sudo rm -rf /var/log/*
sudo rm -f /etc/resolv.conf /var/lib/NetworkManager/* /etc/ssh/ssh_host_*
sudo rm -rf /tmp/ssh-* /tmp/yum* /tmp/tmp* /tmp/*.log* /tmp/*tenant*
sudo rm -f /var/spool/plymouth/boot.log 
sudo rm -f /var/lib/dhclient/* /var/lib/systemd/random-seed
sudo rm -rf /var/cache/*
unset HISTFILE
#rm -f /root/.bash_history
history -c
sudo rm -rf /run/cloud-init /var/lib/cloud/instances/*
yum clean all

# Zero out unused space to minimize actual disk usage
for part in $(awk '$3 == "xfs" {print $2}' /proc/mounts)
do
    dd if=/dev/zero of=${part}/EMPTY bs=1M || true;
    rm -f ${part}/EMPTY
done
sync;

