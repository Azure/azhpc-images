#!/bin/bash

# Disable some unneeded services by default (administrators can re-enable if desired)
systemctl disable firewalld

# Update memory limits
cat << EOF >> /etc/security/limits.conf
*               hard    memlock         unlimited
*               soft    memlock         unlimited
*               hard    nofile          65535
*               soft    nofile          65535
*               hard    stack           unlimited
*               soft    stack           unlimited
EOF

# Enable reclaim mode
echo "vm.zone_reclaim_mode = 1" >> /etc/sysctl.conf
#echo "net.ipv4.neigh.default.gc_thresh1 = 4096" >> /etc/sysctl.conf
#echo "net.ipv4.neigh.default.gc_thresh2 = 8192" >> /etc/sysctl.conf
#echo "net.ipv4.neigh.default.gc_thresh3 = 16384" >> /etc/sysctl.conf
#echo "sunrpc.tcp_max_slot_table_entries = 128" >> /etc/sysctl.conf
sysctl -p

# on SUSE sunrpc get automatically loaded with nfs-client
# if you have problems psl. look at https://www.suse.com/support/kb/doc/?id=000019178

# Remove auoms if exists - Prevent CPU utilization by auoms
if zypper se --installed-only azsec-monitor >/dev/null 2>&1; then zypper --non-interactive remove -y azsec-monitor; fi

# Update WALinuxAgent - for IPoIB
zypper --non-interactive update -y python-azure-agent

# Configure WALinuxAgent
# EnableRDMA=y is already set by default within the SLE HPC image

cat << EOF | tee -a /etc/waagent.conf
# default 6
Extensions.GoalStatePeriod=300
# default 30
OS.RemovePersistentNetRulesPeriod=300
# default 30
OS.MonitorDhcpClientRestartPeriod=60
# default 30
Provisioning.MonitorHostNamePeriod=60
EOF
systemctl restart waagent
$COMMON_DIR/write_component_version.sh "WAAGENT" $(waagent --version | head -n 1 | awk -F' ' '{print $1}' | awk -F- '{print $2}')

# NFS read-ahead limit should be ok, no need for change
# check settings with: cat /sys/class/bdi/*/read_ahead_kb
# https://learn.microsoft.com/en-us/azure/azure-netapp-files/performance-linux-nfs-read-ahead

