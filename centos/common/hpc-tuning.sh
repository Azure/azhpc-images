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
sysctl -p

# Uninstall WALinuxAgent from base image
rpm -e --nodeps WALinuxAgent

# Install Custom WALinuxAgent
WALINUXAGENT_DOWNLOAD_URL=https://github.com/Azure/WALinuxAgent/archive/refs/tags/v2.3.1.1.tar.gz
TARBALL=$(basename ${WALINUXAGENT_DOWNLOAD_URL})
wget $WALINUXAGENT_DOWNLOAD_URL
tar zxvf $TARBALL
pushd WALinuxAgent-2.3.1.1
python setup.py install --register-service
popd

# Configure WALinuxAgent
sudo sed -i -e 's/# OS.EnableRDMA=y/OS.EnableRDMA=y/g' /etc/waagent.conf
echo "Extensions.GoalStatePeriod=120" | sudo tee -a /etc/waagent.conf
echo "OS.EnableFirewallPeriod=300" | sudo tee -a /etc/waagent.conf
echo "OS.RemovePersistentNetRulesPeriod=300" | sudo tee -a /etc/waagent.conf
echo "OS.RootDeviceScsiTimeoutPeriod=300" | sudo tee -a /etc/waagent.conf
echo "OS.MonitorDhcpClientRestartPeriod=60" | sudo tee -a /etc/waagent.conf
echo "Provisioning.MonitorHostNamePeriod=60" | sudo tee -a /etc/waagent.conf
sudo systemctl restart waagent
$COMMON_DIR/write_component_version.sh "WAAGENT" $(python /usr/sbin/waagent --version | grep -o "[0-9].[0-9].[0-9].[0-9]" | head -n 1)
