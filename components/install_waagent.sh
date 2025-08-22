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
fi

update_waagent_conf "OS.EnableRDMA" "y"
update_waagent_conf "Extensions.GoalStatePeriod" "300"
update_waagent_conf "Extensions.InitialGoalStatePeriod" "6"
update_waagent_conf "OS.EnableFirewallPeriod" "300"
update_waagent_conf "OS.RemovePersistentNetRulesPeriod" "300"
update_waagent_conf "OS.RootDeviceScsiTimeoutPeriod" "300"
update_waagent_conf "OS.MonitorDhcpClientRestartPeriod" "60"
update_waagent_conf "Provisioning.MonitorHostName" "y"
update_waagent_conf "Provisioning.MonitorHostNamePeriod" "60"

systemctl daemon-reload
# Restart waagent service in distribution specific file as its name differs between distributions

if [[ $DISTRO_FAMILY == "ubuntu" ]]; then
    systemctl restart walinuxagent
elif [[ $DISTRIBUTION == "almalinux8.10" ]] || [[ $DISTRIBUTION == "azurelinux3.0" ]]; then
    systemctl restart waagent
fi
