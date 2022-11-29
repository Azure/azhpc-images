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
cat << EOF | tee -a /etc/sysctl.conf
vm.zone_reclaim_mode = 1
net.ipv4.neigh.default.gc_thresh1 = 4096
net.ipv4.neigh.default.gc_thresh2 = 8192
net.ipv4.neigh.default.gc_thresh3 = 16384
sunrpc.tcp_max_slot_table_entries = 128
EOF

## Systemd service for starting sunrpc and adding setting parameters
cat <<EOF >/usr/sbin/sunrpc_tcp_settings.sh
#!/bin/bash

modprobe sunrpc
sysctl -p
EOF

chmod 755 /usr/sbin/sunrpc_tcp_settings.sh

cat <<EOF >/etc/systemd/system/sunrpc_tcp_settings.service
[Unit]
Description=Set sunrpc tcp settings

[Service]
User=root
Type=oneshot
ExecStart=/usr/sbin/sunrpc_tcp_settings.sh
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF

systemctl enable sunrpc_tcp_settings
systemctl start sunrpc_tcp_settings
systemctl is-active --quiet sunrpc_tcp_settings

error_code=$?
if [ ${error_code} -ne 0 ]
then
    echo "sunrpc_tcp_settings service inactive!"
    exit ${error_code}
fi

## Delete Azsec from the VM
# Disable epel-azsec.repo
EPEL_AZSEC_REPO="/etc/yum.repos.d/epel-azsec.repo"
if [ -f ${EPEL_AZSEC_REPO} ]; then sed -i -e 's/enabled=1/enabled=0/g' ${EPEL_AZSEC_REPO}; fi
# Remove auoms if exists - Prevent CPU utilization by auoms
if yum list installed azsec-monitor >/dev/null 2>&1; then yum remove -y azsec-monitor; fi

# Update WALinuxAgent - for IPoIB
yum update -y WALinuxAgent

# Configure WALinuxAgent
sed -i -e 's/# OS.EnableRDMA=y/OS.EnableRDMA=y/g' /etc/waagent.conf
cat << EOF | tee -a /etc/waagent.conf
Extensions.GoalStatePeriod=300
Extensions.InitialGoalStatePeriod=6
OS.EnableFirewallPeriod=300
OS.RemovePersistentNetRulesPeriod=300
OS.RootDeviceScsiTimeoutPeriod=300
OS.MonitorDhcpClientRestartPeriod=60
Provisioning.MonitorHostNamePeriod=60
EOF

## waagent service is based on /usr/bin/python for CentOS 8
# ln -sf /usr/bin/python3 /usr/bin/python

## Restart waagent service to apply changes
systemctl restart waagent
systemctl is-active --quiet waagent

error_code=$?
if [ ${error_code} -ne 0 ]
then
    echo "waagent service inactive/dead!"
    exit ${error_code}
fi
$COMMON_DIR/write_component_version.sh "WAAGENT" $(waagent --version | head -n 1 | awk -F' ' '{print $1}' | awk -F- '{print $2}')
