#!/bin/bash
set -ex

# Set waagent version and sha256
waagent_metadata=$(jq -r '.waagent."'"$DISTRIBUTION"'"' <<< $COMPONENT_VERSIONS)
WAAGENT_VERSION=$(jq -r '.version' <<< $waagent_metadata)
WAAGENT_SHA256=$(jq -r '.sha256' <<< $waagent_metadata)

# Install newest WALinuxAgent. Ubuntu package manager has an old version of WALinuxAgent
apt-get install -y python3-setuptools
pip3 install distro

DOWNLOAD_URL=https://github.com/Azure/WALinuxAgent/archive/refs/tags/v${WAAGENT_VERSION}.tar.gz
$COMMON_DIR/download_and_verify.sh ${DOWNLOAD_URL} ${WAAGENT_SHA256}
tar -xvf $(basename ${DOWNLOAD_URL})
pushd WALinuxAgent-${WAAGENT_VERSION}/
python3 setup.py install --register-service
popd

# Configure WALinuxAgent
sed -i -e 's/# OS.EnableRDMA=y/OS.EnableRDMA=y/g' /etc/waagent.conf
sed -i -e 's/Provisioning.MonitorHostName=n/Provisioning.MonitorHostName=y/g' /etc/waagent.conf

$COMMON_DIR/install_waagent.sh

systemctl daemon-reload
systemctl restart walinuxagent

$COMMON_DIR/write_component_version.sh "WAAGENT" $(waagent --version | head -n 1 | awk -F' ' '{print $1}' | awk -F- '{print $2}')
$COMMON_DIR/write_component_version.sh "WAAGENT_EXTENSIONS" $(waagent --version | head -n 3 | awk -F' ' '{print $4}')
