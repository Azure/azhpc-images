#!/bin/bash
set -ex

# Clear History
rm -rf /var/log/*
rm -f /etc/ssh/ssh_host_*
rm -rf /tmp/ssh-* /tmp/yum* /tmp/tmp* /tmp/*.log* /tmp/*tenant*
rm -rf /tmp/nvidia* /tmp/MLNX* /tmp/ofed.conf /tmp/dkms* /tmp/*mlnx*
rm -f /var/lib/systemd/random-seed
rm -rf /var/cache/*
unset HISTFILE
#rm -f /root/.bash_history
history -c
rm -rf /run/cloud-init /var/lib/cloud/instances/*
yum clean all

# Zero out unused space to minimize actual disk usage
for part in $(awk '$3 == "xfs" {print $2}' /proc/mounts)
do
    dd if=/dev/zero of=${part}/EMPTY bs=1M || true;
    rm -f ${part}/EMPTY
done
sync;

