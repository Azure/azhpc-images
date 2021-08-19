#!/bin/bash
set -ex

# Remove logs, cache, temporary installation dir and other host info
rm -rf /var/log/*
rm -f /etc/ssh/ssh_host_*
rm -rf /tmp/nccl* /tmp/*.gz /tmp/nvidia* /tmp/MLNX* /tmp/*.log* /tmp/ofed.conf
rm -f /var/lib/systemd/random-seed
rm -rf /var/cache/*
rm -rf /run/cloud-init /var/lib/cloud/instances/*

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
