#!/bin/bash
set -ex

# Remove logs, cache, temporary installation dir and other host info
rm -rf /var/log/*
rm -f /etc/ssh/ssh_host_*
rm -rf /tmp/*.gz /tmp/nvidia* /tmp/MLNX* /tmp/*.log* /tmp/ofed.conf /tmp/tmp*
rm -rf /var/lib/systemd/random-seed /var/intel/ /var/cache/* /var/lib/cloud/instances/*
rm -rf /run/cloud-init
rm -rf /root/intel/

# Empty machine information
cat /dev/null > /etc/machine-id

# Clear bash history
cat /dev/null > ~/.bash_history && history -c
export HISTSIZE=0
apt-get clean

# Zero out unused space to minimize actual disk usage
for part in $(awk '$3 == "xfs" {print $2}' /proc/mounts)
do
    dd if=/dev/zero of=${part}/EMPTY bs=1M || true;
    rm -f ${part}/EMPTY
done
sync;
