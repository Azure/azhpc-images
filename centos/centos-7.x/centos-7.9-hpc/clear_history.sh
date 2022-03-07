#!/bin/bash
set -ex

# Sync yum and rpmdb after installing rpm's outside yum
yum history sync

# Clear History
rm -rf /var/log/*
rm -f /etc/ssh/ssh_host_*
rm -rf /tmp/ssh-* /tmp/yum* /tmp/tmp* /tmp/*.log* /tmp/*tenant*
rm -rf /tmp/nvidia* /tmp/MLNX* /tmp/ofed.conf /tmp/dkms* /tmp/*mlnx*
rm -rf /var/lib/systemd/random-seed /var/intel/ /var/cache/*
rm -rf /run/cloud-init /var/lib/cloud/instances/*
rm -rf /root/intel/

# Empty machine information
cat /dev/null > /etc/machine-id

yum clean all
du -sh /var/cache/yum/x86_64/7/*

# Zero out unused space to minimize actual disk usage
for part in $(awk '$3 == "xfs" {print $2}' /proc/mounts)
do
    dd if=/dev/zero of=${part}/EMPTY bs=1M || true;
    rm -f ${part}/EMPTY
done
sync;

unset HISTFILE
#rm -f /root/.bash_history
history -c
