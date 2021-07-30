#!/bin/bash

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
sysctl -p

# Install WALinuxAgent
apt-get install python3-setuptools
WALINUXAGENT_DOWNLOAD_URL=https://github.com/Azure/WALinuxAgent/archive/refs/tags/v2.3.1.1.tar.gz
TARBALL=$(basename ${WALINUXAGENT_DOWNLOAD_URL})
wget $WALINUXAGENT_DOWNLOAD_URL
tar zxvf $TARBALL
cd WALinuxAgent-2.3.1.1
python3 setup.py install --register-service

# Configure WALinuxAgent
sed -i -e 's/# OS.EnableRDMA=y/OS.EnableRDMA=y/g' /etc/waagent.conf
echo "Extensions.GoalStatePeriod=120" | sudo tee -a /etc/waagent.conf
echo "OS.EnableFirewallPeriod=300" | sudo tee -a /etc/waagent.conf
echo "OS.RemovePersistentNetRulesPeriod=300" | sudo tee -a /etc/waagent.conf
echo "OS.RootDeviceScsiTimeoutPeriod=300" | sudo tee -a /etc/waagent.conf
echo "OS.MonitorDhcpClientRestartPeriod=60" | sudo tee -a /etc/waagent.conf
echo "Provisioning.MonitorHostNamePeriod=60" | sudo tee -a /etc/waagent.conf
systemctl restart walinuxagent
