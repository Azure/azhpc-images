#!/bin/bash
set -ex

# TODO: migrate this script back into clear_history.sh once we completely move off of non-Packer pipeline

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
