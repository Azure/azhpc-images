#!/bin/bash
set -ex

# Sync yum and rpmdb after installing rpm's outside yum
yum history sync

# Clear History
# Delete sensitive log files
rm -rf /var/log/audit/audit.log /var/log/secure /var/log/messages
# Clear contents of rest of systemd services related log files
for log in $(find /var/log/ -type f -name '*.log'); do cat /dev/null > $log; done
rm -rf /var/lib/systemd/random-seed 
rm -rf /var/intel/ /var/cache/* /var/lib/cloud/instances/*
rm -rf /var/lib/hyperv/.kvp_pool_0
rm -f /etc/ssh/ssh_host_* /etc/sudoers.d/* /etc/*-
rm -rf /tmp/ssh-* /tmp/yum* /tmp/tmp* /tmp/*.log* /tmp/*tenant*
rm -rf /tmp/nvidia* /tmp/MLNX* /tmp/ofed.conf /tmp/dkms* /tmp/*mlnx*
rm -rf /run/cloud-init
rm -rf /root/*
rm -rf /usr/tmp/dnf*
# Clear contents of nccl.conf
cat /dev/null > /etc/nccl.conf

# Empty machine information
cat /dev/null > /etc/machine-id

yum clean all

# Zero out unused space to minimize actual disk usage
for part in $(awk '$3 == "xfs" {print $2}' /proc/mounts)
do
    dd if=/dev/zero of=${part}/EMPTY bs=1M || true;
    rm -f ${part}/EMPTY
done
sync;

export HISTSIZE=0 && history -c && sync
