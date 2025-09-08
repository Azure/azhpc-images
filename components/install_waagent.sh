#!/bin/bash
set -ex

source ${UTILS_DIR}/utilities.sh

function update_waagent_conf {
    key=$1
    value=$2

    # Check if the key exists in the file
    if grep -q "^$key=" /etc/waagent.conf; then
        # Update the value if the key exists
        sed -i "s/^$key=.*/$key=$value/" /etc/waagent.conf
    else
        # Add the key-value pair if the key does not exist
        echo "$key=$value" >> /etc/waagent.conf
    fi
}

if [[ $DISTRIBUTION == "azurelinux3.0" ]]; then
    # Update WALinuxAgent - for IPoIB
    tdnf update -y WALinuxAgent

    update_waagent_conf "OS.EnableRDMA" "y"
    update_waagent_conf "Extensions.GoalStatePeriod" "300"
    update_waagent_conf "Extensions.GoalStatePeriod" "300"
    update_waagent_conf "Extensions.InitialGoalStatePeriod" "6"
    update_waagent_conf "OS.EnableFirewallPeriod" "300"
    update_waagent_conf "OS.RemovePersistentNetRulesPeriod" "300"
    update_waagent_conf "OS.RootDeviceScsiTimeoutPeriod" "300"
    update_waagent_conf "OS.MonitorDhcpClientRestartPeriod" "60"
    update_waagent_conf "Provisioning.MonitorHostNamePeriod" "60"
else
    # Set waagent version and sha256
    waagent_metadata=$(get_component_config "waagent")
    WAAGENT_VERSION=$(jq -r '.version' <<< $waagent_metadata)
    WAAGENT_SHA256=$(jq -r '.sha256' <<< $waagent_metadata)

    # Update WALinuxAgent - for IPoIB support
    DOWNLOAD_URL=https://github.com/Azure/WALinuxAgent/archive/refs/tags/v${WAAGENT_VERSION}.tar.gz
    download_and_verify ${DOWNLOAD_URL} ${WAAGENT_SHA256}
    tar -xvf $(basename ${DOWNLOAD_URL})
    pushd WALinuxAgent-${WAAGENT_VERSION}/
    python3 setup.py install --register-service
    popd

    # Configure WALinuxAgent
    update_waagent_conf "Extensions.GoalStatePeriod" "300"
    update_waagent_conf "Extensions.InitialGoalStatePeriod" "6"
    update_waagent_conf "OS.EnableFirewallPeriod" "300"
    update_waagent_conf "OS.EnableRDMA" "y"
    update_waagent_conf "OS.RemovePersistentNetRulesPeriod" "300"
    update_waagent_conf "OS.RootDeviceScsiTimeoutPeriod" "300"
    update_waagent_conf "OS.MonitorDhcpClientRestartPeriod" "60"
    update_waagent_conf "Provisioning.MonitorHostName" "y"
    update_waagent_conf "Provisioning.MonitorHostNamePeriod" "60"
    rm -rf WALinuxAgent-${WAAGENT_VERSION}
fi

write_component_version "WAAGENT" $(waagent --version | head -n 1 | awk -F' ' '{print $1}' | awk -F- '{print $2}')
write_component_version "WAAGENT_EXTENSIONS" $(waagent --version | sed '3q;d' | awk -F' ' '{print $4}')

systemctl daemon-reload
# Restart waagent service in distribution specific file as its name differs between distributions

if [[ $DISTRIBUTION == ubuntu* ]]; then
    systemctl restart walinuxagent
elif [[ $DISTRIBUTION == almalinux* ]] || [[ $DISTRIBUTION == "azurelinux3.0" ]]; then
    systemctl restart waagent
fi

echo "Waiting to avoid waagent taking package manager locks..."
sleep 60