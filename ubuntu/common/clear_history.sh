#!/bin/bash
set -ex

# Remove logs, cache, temporary installation dir and other host info
rm -rf /var/log/* /var/lib/systemd/random-seed
rm -rf /var/intel/ /var/cache/* /var/lib/cloud/instances/*
rm -f /etc/ssh/ssh_host_* /etc/sudoers.d/* /etc/*-
rm -rf /tmp/*.gz /tmp/nvidia* /tmp/MLNX* /tmp/*.log* /tmp/ofed.conf /tmp/tmp*
rm -rf /run/cloud-init
rm -rf /root/*

# Empty machine information
cat /dev/null > /etc/machine-id

# Zero out unused space to minimize actual disk usage
for part in $(awk '$3 == "xfs" {print $2}' /proc/mounts)
do
    dd if=/dev/zero of=${part}/EMPTY bs=1M || true;
    rm -f ${part}/EMPTY
done
sync;

apt-get clean
cat /dev/null > ~/.bash_history
export HISTSIZE=0 && history -c && sync
