#!/bin/bash
set -ex

# Install Dependencies
pip3 install -U netifaces
pip3 install -U PyYAML

# Disable some unneeded services by default (administrators can re-enable if desired)
systemctl disable ufw

# Disable cloud-init
echo network: {config: disabled} | sudo tee /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg
bash -c "cat > /etc/netplan/50-cloud-init.yaml" <<'EOF'
network:
    ethernets:
        eth0:
            dhcp4: true
    version: 2
EOF
netplan apply

# Update memory limits
cat << EOF >> /etc/security/limits.conf
*               hard    memlock         unlimited
*               soft    memlock         unlimited
*               hard    nofile          65535
*               soft    nofile          65535
*               hard    stack           unlimited
*               soft    stack           unlimited
EOF

echo "vm.zone_reclaim_mode = 1" >> /etc/sysctl.conf
echo "sunrpc.tcp_max_slot_table_entries=128" >> /etc/sysctl.conf
echo "net.ipv4.neigh.default.gc_thresh1 4096" >> /etc/sysctl.conf
echo "net.ipv4.neigh.default.gc_thresh2 8192" >> /etc/sysctl.conf
echo "net.ipv4.neigh.default.gc_thresh3 16384" >> /etc/sysctl.conf
sysctl -p

# Install WALinuxAgent
apt-get install python3-setuptools
pip3 install distro
WAAGENT_VERSION=2.5.0.2
$COMMON_DIR/write_component_version.sh "WAAGENT" ${WAAGENT_VERSION}
DOWNLOAD_URL=https://github.com/Azure/WALinuxAgent/archive/refs/tags/v${WAAGENT_VERSION}.tar.gz
wget ${DOWNLOAD_URL}
tar -xvf $(basename ${DOWNLOAD_URL})
pushd WALinuxAgent-${WAAGENT_VERSION}/
python3 setup.py install --register-service
popd

# Configure WALinuxAgent
sed -i -e 's/# OS.EnableRDMA=y/OS.EnableRDMA=y/g' /etc/waagent.conf
echo "Extensions.GoalStatePeriod=300" | sudo tee -a /etc/waagent.conf
echo "Extensions.InitialGoalStatePeriod=6" | sudo tee -a /etc/waagent.conf
echo "OS.EnableFirewallPeriod=300" | sudo tee -a /etc/waagent.conf
echo "OS.RemovePersistentNetRulesPeriod=300" | sudo tee -a /etc/waagent.conf
echo "OS.RootDeviceScsiTimeoutPeriod=300" | sudo tee -a /etc/waagent.conf
echo "OS.MonitorDhcpClientRestartPeriod=60" | sudo tee -a /etc/waagent.conf
echo "Provisioning.MonitorHostNamePeriod=60" | sudo tee -a /etc/waagent.conf
systemctl daemon-reload
systemctl restart walinuxagent
