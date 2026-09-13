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
    elif [[ $os == "Rocky Linux" ]]
    then
        local rocky_distro=`find_rocky_distro`
        echo "${os} ${rocky_distro}"
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

# Find Rocky distro
# Rocky Linux release 8.10 (Green Obsidian) -> version is field $4
find_rocky_distro() {
    echo `cat /etc/redhat-release | awk '{print $4}'`
}

# Find RHEL distro
# Red Hat Enterprise Linux release 8.10 (Ootpa) -> version is field $6
find_rhel_distro() {
    echo `cat /etc/redhat-release | awk '{print $6}'`
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

verify_final_cleanup() {
    local path

    if [[ ${distro} == *"Ubuntu"* ]] && \
        dpkg -l 2>/dev/null | grep -qE '^(ii|rc|hi|ri|pi|ip|in)[[:space:]]+(mdatp|microsoft-mdatp)(:|[[:space:]])'; then
        echo "ERROR: mdatp has a dpkg state before image capture"
        dpkg -l 2>/dev/null | grep -E '(mdatp|microsoft-mdatp)' || true
        return 1
    elif [[ ${distro} != *"Ubuntu"* ]] && {
        rpm -q mdatp >/dev/null 2>&1 || rpm -q microsoft-mdatp >/dev/null 2>&1
    }; then
        echo "ERROR: mdatp package is still present before image capture"
        return 1
    fi

    if [[ ${distro} == *"Ubuntu"* ]] && {
        compgen -G '/var/lib/dpkg/info/mdatp.*' >/dev/null ||
            compgen -G '/var/lib/dpkg/info/microsoft-mdatp.*' >/dev/null
    }; then
        echo "ERROR: mdatp dpkg metadata is still present before image capture"
        ls -la /var/lib/dpkg/info/mdatp.* /var/lib/dpkg/info/microsoft-mdatp.* 2>/dev/null || true
        return 1
    fi

    if command -v mdatp >/dev/null 2>&1; then
        echo "ERROR: mdatp executable is still present before image capture"
        return 1
    fi

    if command -v systemctl >/dev/null 2>&1 && {
        systemctl cat mdatp.service >/dev/null 2>&1 ||
            systemctl list-unit-files 2>/dev/null | grep -qw mdatp.service
    }; then
        echo "ERROR: mdatp.service is still present before image capture"
        systemctl status mdatp.service 2>/dev/null || true
        return 1
    fi

    if pgrep -x wdavdaemon >/dev/null 2>&1; then
        echo "ERROR: wdavdaemon is still running before image capture"
        pgrep -a -x wdavdaemon || true
        return 1
    fi

    for path in \
        /opt/microsoft/mdatp \
        /opt/microsoft/mde \
        /var/opt/microsoft/mdatp \
        /etc/opt/microsoft/mdatp \
        /etc/opt/microsoft/mdatp_onboard.json \
        /var/log/microsoft/mdatp \
        /etc/audit/rules.d/mdatp.rules \
        /etc/apparmor.d/mdatp \
        /etc/apparmor.d/disable/mdatp \
        /usr/lib/systemd/system/mdatp.service \
        /etc/systemd/system/multi-user.target.wants/mdatp.service \
        /var/lib/dpkg/info/mdatp.list \
        /var/lib/dpkg/info/mdatp.md5sums \
        /var/lib/dpkg/info/mdatp.postinst \
        /var/lib/dpkg/info/mdatp.postrm \
        /var/lib/dpkg/info/mdatp.preinst \
        /var/lib/dpkg/info/mdatp.prerm \
        /var/lib/dpkg/info/mdatp.conffiles; do
        if [[ -e ${path} || -L ${path} ]]; then
            echo "ERROR: MDE path is still present before image capture: ${path}"
            return 1
        fi
    done

    for path in \
        '/var/lib/waagent/*MDE.Linux*' \
        '/var/log/azure/*MDE.Linux*' \
        '/var/lib/GuestConfig/extension_logs/*MDE.Linux*'; do
        if compgen -G "${path}" >/dev/null; then
            echo "ERROR: MDE extension residue is still present before image capture: ${path}"
            return 1
        fi
    done

    if find / -xdev -type f \( -name 'eicar.com*' -o -name 'utils_58.py' \) \
        -not -path '/proc/*' -not -path '/sys/*' -print -quit 2>/dev/null | grep -q .; then
        echo "ERROR: EICAR test artifact is still present before image capture"
        return 1
    fi
}

# The Azure guest agent can auto-provision MDE again after clear_history.sh has
# removed it. Stop the agent before the final package cleanup so no extension
# operation can race image capture.
if command -v systemctl >/dev/null 2>&1; then
    systemctl stop walinuxagent.service 2>/dev/null || true
    systemctl stop waagent.service 2>/dev/null || true
fi

# Purge mdatp again immediately before image capture. The first purge happens
# in clear_history.sh, but MDE may have been auto-provisioned again afterwards.
if [[ ${distro} == *"Ubuntu"* ]]; then
    if dpkg -l | grep -qw mdatp; then
        DEBIAN_FRONTEND=noninteractive apt-get purge -y mdatp
    fi
elif [[ ${distro} == *"Azure Linux"* ]]; then
    if rpm -q mdatp >/dev/null 2>&1; then
        dnf remove -y mdatp
    fi
else
    if rpm -q mdatp >/dev/null 2>&1; then
        dnf remove -y mdatp
    fi
fi

# Remove the AzNHC log
sudo rm -f /opt/azurehpc/test/azurehpc-health-checks/health.log

# Uninstall the OMS Agent
wget -qO- https://raw.githubusercontent.com/microsoft/OMS-Agent-for-Linux/master/installer/scripts/uninstall.sh | sudo bash

# Remove both agent data and extension state. These paths are checked by the
# LISA certification script and must not be baked into the captured image.
rm -rf \
    /opt/microsoft/mdatp \
    /opt/microsoft/mde \
    /var/opt/microsoft/mdatp \
    /etc/opt/microsoft/mdatp \
    /etc/opt/microsoft/mdatp_onboard.json \
    /var/log/microsoft/mdatp \
    /etc/audit/rules.d/mdatp.rules \
    /etc/apparmor.d/mdatp \
    /etc/apparmor.d/disable/mdatp \
    /usr/lib/systemd/system/mdatp.service \
    /etc/systemd/system/multi-user.target.wants/mdatp.service \
    /var/lib/dpkg/info/mdatp.list \
    /var/lib/dpkg/info/mdatp.md5sums \
    /var/lib/dpkg/info/mdatp.postinst \
    /var/lib/dpkg/info/mdatp.postrm \
    /var/lib/dpkg/info/mdatp.preinst \
    /var/lib/dpkg/info/mdatp.prerm \
    /var/lib/dpkg/info/mdatp.conffiles \
    /var/lib/waagent/*MDE.Linux* \
    /var/log/azure/*MDE.Linux* \
    /var/lib/GuestConfig/extension_logs/*MDE.Linux*

# Remove Defender test artifacts without crossing into mounted data disks.
find / -xdev -type f \( -name 'eicar.com*' -o -name 'utils_58.py' \) \
    -not -path '/proc/*' -not -path '/sys/*' -delete 2>/dev/null || true

if command -v systemctl >/dev/null 2>&1; then
    systemctl daemon-reload
fi
verify_final_cleanup


# Switch to the root user
sudo -s <<EOF
if [[ "${TARGET_NODE_TYPE:-azure_vm_regular}" != "baremetal_1p" ]]; then
    # Empty machine information
    cat /dev/null > /etc/machine-id

    rm -f /etc/ssh/ssh_host_*
    rm -f ~/.ssh/authorized_keys
    (
        shopt -s dotglob nullglob
        rm -rf -- /root/*
    )

    # Disable root account
    usermod root -p '!!'
    # Deprovision the user
    waagent -deprovision+user -force
else
    apt -y remove walinuxagent 2>/dev/null || true
fi

# Delete the last line of the file /etc/sysconfig/network-scripts/ifcfg-eth0 -> cloud-init issue on alma distros
if [[ "$distro" == *"AlmaLinux"* ]] || [[ "$distro" == *"Rocky"* ]] || [[ "$distro" == *"Red Hat"* ]]
then
    sed -i '$ d' /etc/sysconfig/network-scripts/ifcfg-eth0
fi

if [[ "${TARGET_NODE_TYPE:-azure_vm_regular}" != "baremetal_1p" ]]; then
    # Clear the sudoers.d folder - last user information
    (
        shopt -s dotglob nullglob
        rm -rf -- /etc/sudoers.d/*
    )
fi

# Delete /1 folder
rm -rf /1

touch /var/run/utmp
# clear command history
cat /dev/null > ~/.bash_history
export HISTSIZE=0 && history -c && sync
EOF
