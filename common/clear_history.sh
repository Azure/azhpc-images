#!/bin/bash
set -ex

os=`cat /etc/os-release | awk 'match($0, /^NAME="(.*)"/, result) { print result[1] }'`
if [[ $os == "CentOS Linux" ]] || [[ $os == "AlmaLinux" ]]
then
    # Sync yum and rpmdb after installing rpm's outside yum
    yum history sync
fi

# Clear History
# Delete sensitive log files
rm -rf /var/log/audit/audit.log /var/log/secure /var/log/messages
# Clear contents of rest of systemd services related log files
for log in $(find /var/log/ -type f -name '*.log'); do cat /dev/null > $log; done

rm -rf /var/lib/systemd/random-seed 
rm -rf /var/intel/ /var/cache/* /var/lib/cloud/instances/*
rm -rf /var/lib/hyperv/.kvp_pool_0
rm -f /etc/ssh/ssh_host_* /etc/sudoers.d/* /etc/*-
rm -rf /tmp/ssh-* /tmp/yum* /tmp/tmp* /tmp/*.log* /tmp/*tenant* /tmp/*.gz
rm -rf /tmp/nvidia* /tmp/MLNX* /tmp/ofed.conf /tmp/dkms* /tmp/*mlnx*
rm -rf /run/cloud-init
rm -rf /root/*
rm -rf /usr/tmp/dnf*

# Clear contents of nccl.conf
cat /dev/null > /etc/nccl.conf

# Empty machine information
cat /dev/null > /etc/machine-id

if [[ $os == "Ubuntu" ]]
then
    apt-get clean
else
    yum clean all
fi

# Zero out unused space to minimize actual disk usage
for part in $(awk '$3 == "xfs" {print $2}' /proc/mounts)
do
    dd if=/dev/zero of=${part}/EMPTY bs=1M || true;
    rm -f ${part}/EMPTY
done
sync;

cat /dev/null > ~/.bash_history
export HISTSIZE=0 && history -c && sync
