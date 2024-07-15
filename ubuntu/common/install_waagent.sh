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
sed -i -e 's/Provisioning.MonitorHostName=n/Provisioning.MonitorHostName=y/g' /etc/waagent.conf

$COMMON_DIR/install_waagent.sh

systemctl daemon-reload
systemctl restart walinuxagent

$COMMON_DIR/write_component_version.sh "WAAGENT" ${WAAGENT_VERSION}
