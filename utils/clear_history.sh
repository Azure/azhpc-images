#!/bin/bash
set -ex

# Find distro
find_distro() {
    local os=`cat /etc/os-release | awk 'match($0, /^NAME="(.*)"/, result) { print result[1] }'`
    if [[ $os == "AlmaLinux" ]]
    then
        local alma_distro=`find_alma_distro`
        echo "${os} ${alma_distro}"
    elif [[ $os == "Red Hat Enterprise Linux" ]]
    then
        local rhel_distro=`find_rhel_distro`
        echo "${os} ${rhel_distro}"
    elif [[ $os == "Ubuntu" ]]
    then
        local ubuntu_distro=`find_ubuntu_distro`
        echo "${os} ${ubuntu_distro}"
    elif [[ $os == "Microsoft Azure Linux" ]]
    then
        local azurelinux_distro=`find_azurelinux_distro`
        echo "${os} ${azurelinux_distro}"
    else
        echo "*** Error - invalid distro!"
        exit -1
    fi
}

# Find Alma distro
find_alma_distro() {
    echo `cat /etc/redhat-release | awk '{print $3}'`
}

# Find RHEL distro
find_rhel_distro() {
    echo `cat /etc/redhat-release | awk '{print $3}'`
}

# Find Ubuntu distro
find_ubuntu_distro() {
    echo `cat /etc/os-release | awk 'match($0, /^PRETTY_NAME="(.*)"/, result) { print result[1] }' | awk '{print $2}' | cut -d. -f1,2`
}

# Find Azure Linux distro
find_azurelinux_distro() {
    echo `cat /etc/os-release | awk 'match($0, /^PRETTY_NAME="(.*)"/, result) { print result[1] }' | awk '{print $2$3}' | cut -d. -f1,2`
}

distro=`find_distro`
echo "Detected distro: ${distro}"

if [[ $distro == *"AlmaLinux"* ]]
then
    # Sync yum and rpmdb after installing rpm's outside yum
    yum history sync
fi

if [[ $distro == *"AzureLinux"* ]]
then
    # Sync yum and rpmdb after installing rpm's outside yum
    tdnf history sync
fi

if [[ $distro == *"Ubuntu"* ]]
then
    # Remove Defender
    if dpkg -l | grep -qw mdatp; then
        apt-get purge -y mdatp
    fi

    # Remove Azure Proxy Agent
    # Azure Proxy Agent is introduced in from 24.04.202512100 of Ubuntu images. It provides process-level authentication and authorization 
    # for access to Azure IMDS and WireServer metadata endpoint, which will block core-dns from accessing metadata endpoint causing issues in some scenarios
    # and conflicts with eBPF programs intercepted by Kubernetes CNI. 
    # See https://learn.microsoft.com/en-us/azure/virtual-machines/metadata-security-protocol/overview, https://github.com/Azure/GuestProxyAgent/issues/295
    if dpkg -l | grep -qw azure-proxy-agent; then
        apt-get purge -y azure-proxy-agent
    fi

elif [[ $distro == *"AzureLinux"* ]]
then
    if tdnf list installed | grep -qw mdatp; then
        tdnf remove -y mdatp
    fi
else
    if yum list installed | grep -qw mdatp; then
        yum remove -y mdatp
    fi
fi

# Clear History
# Stop syslog service
systemctl stop syslog.socket rsyslog
# Delete Defender related files
rm -rf /var/log/microsoft/mdatp /etc/opt/microsoft/mdatp /var/lib/waagent/Microsoft.Azure.AzureDefenderForServers.MDE.Linux* /var/log/azure/Microsoft.Azure.AzureDefenderForServers.MDE.Linux* /var/lib/GuestConfig/extension_logs/Microsoft.Azure.AzureDefenderForServers.MDE.Linux*
# Delete sensitive log files
rm -rf /var/log/audit/audit.log /var/log/secure /var/log/messages /var/log/auth.log /var/log/syslog
# Delete AzurePolicyforLinux related files
rm -rf /usr/lib/systemd/system/gcd.service
rm -rf /var/lib/GuestConfig
# Clear contents of rest of systemd services related log files
for log in $(find /var/log/ -type f -name '*.log'); do cat /dev/null > $log; done

rm -rf /var/lib/systemd/random-seed 
rm -rf /var/intel/ /var/cache/* /var/lib/cloud/instances/*
rm -rf /var/lib/hyperv/.kvp_pool_0
rm -f /etc/ssh/ssh_host_* /etc/*-
rm -f ~/.ssh/authorized_keys
rm -rf /tmp/ssh-* /tmp/yum* /tmp/tmp* /tmp/*.log* /tmp/*tenant* /tmp/*.gz
rm -rf /tmp/nvidia* /tmp/MLNX* /tmp/ofed.conf /tmp/dkms* /tmp/*mlnx*
rm -rf /run/cloud-init
rm -rf /root/*
rm -rf /usr/tmp/dnf*
# rm -rf /etc/sudoers.d/*

if systemctl is-active --quiet sku-customizations
then
    # Stop the sku-customizations service
    systemctl stop sku-customizations
fi

# Empty machine information
cat /dev/null > /etc/machine-id

if [[ $distro == *"Ubuntu"* ]]
then
    apt-get clean
elif [[ $distro == *"AzureLinux"* ]]
then
    tdnf clean all
else
    yum clean all
fi

# Zero out unused space to minimize actual disk usage
for part in $(awk '$3 == "xfs" {print $2}' /proc/mounts)
do
    dd if=/dev/zero of=${part}/EMPTY bs=1M || true;
    rm -f ${part}/EMPTY
done
sync;

# Remove the AzNHC log
sudo rm -f /opt/azurehpc/test/azurehpc-health-checks/health.log

# Uninstall the OMS Agent
wget -qO- https://raw.githubusercontent.com/microsoft/OMS-Agent-for-Linux/master/installer/scripts/uninstall.sh | sudo bash

# Switch to the root user
sudo -s <<EOF
# Disable root account
usermod root -p '!!'
# Deprovision the user
waagent -deprovision+user -force
# Delete the last line of the file /etc/sysconfig/network-scripts/ifcfg-eth0 -> cloud-init issue on alma distros
if [[ "$distro" == *"AlmaLinux"*  ]]
then
    sed -i '$ d' /etc/sysconfig/network-scripts/ifcfg-eth0
fi
# Clear the sudoers.d folder - last user information
rm -rf /etc/sudoers.d/*
# Delete /1 folder
rm -rf /1
touch /var/run/utmp
# clear command history
cat /dev/null > ~/.bash_history
export HISTSIZE=0 && history -c && sync
EOF
