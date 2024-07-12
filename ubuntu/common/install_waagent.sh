#!/bin/bash
set -ex

# Set waagent version and sha256
waagent_metadata=$(jq -r '.waagent."'"$DISTRIBUTION"'"' <<< $COMPONENT_VERSIONS)
WAAGENT_VERSION=$(jq -r '.version' <<< $waagent_metadata)

# Install WALinuxAgent
apt-get install -y python3-setuptools
pip3 install distro
$COMMON_DIR/write_component_version.sh "WAAGENT" ${WAAGENT_VERSION}
DOWNLOAD_URL=https://github.com/Azure/WALinuxAgent/archive/refs/tags/v${WAAGENT_VERSION}.tar.gz
wget ${DOWNLOAD_URL}
tar -xvf $(basename ${DOWNLOAD_URL})
pushd WALinuxAgent-${WAAGENT_VERSION}/
python3 setup.py install --register-service
popd

# Configure WALinuxAgent
sed -i -e 's/# OS.EnableRDMA=y/OS.EnableRDMA=y/g' /etc/waagent.conf
sed -i -e 's/Provisioning.MonitorHostName=n/Provisioning.MonitorHostName=y/g' /etc/waagent.conf
echo "Extensions.GoalStatePeriod=300" | sudo tee -a /etc/waagent.conf
echo "Extensions.InitialGoalStatePeriod=6" | sudo tee -a /etc/waagent.conf
echo "OS.EnableFirewallPeriod=300" | sudo tee -a /etc/waagent.conf
echo "OS.RemovePersistentNetRulesPeriod=300" | sudo tee -a /etc/waagent.conf
echo "OS.RootDeviceScsiTimeoutPeriod=300" | sudo tee -a /etc/waagent.conf
echo "OS.MonitorDhcpClientRestartPeriod=60" | sudo tee -a /etc/waagent.conf
echo "Provisioning.MonitorHostNamePeriod=60" | sudo tee -a /etc/waagent.conf
systemctl daemon-reload
systemctl restart walinuxagent

$COMMON_DIR/write_component_version.sh "WAAGENT" ${WAAGENT_VERSION}
