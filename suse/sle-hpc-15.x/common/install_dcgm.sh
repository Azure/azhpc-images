#!/bin/bash
set -ex

# Install DCGM

# workaround to create group for serviceUser=nvidia-dcgm
# as the package expects that the variable "USERGROUPS_ENAB" in /etc/login.defs is set to yes
# in oder that the useradd create the group too, but the SUSE default is "no", so we would change the
# variable or simply use the parameter -U
# wrong cmd: useradd -r -M -s /usr/sbin/nologin ${serviceUser}
# right cmd: useradd -r -M -U -s /usr/sbin/nologin ${serviceUser}
# see: man useradd
# bug reported to Nvidia
serviceUser="nvidia-dcgm"

#check if user exists, if not create it
if ! id $serviceUser &>/dev/null; then
   useradd -r -M -U -s /usr/sbin/nologin ${serviceUser}
fi
zypper --non-interactive install -y -l datacenter-gpu-manager = ${DCGM_VERSION}

systemctl --now enable nvidia-dcgm

# Check if the service is active
systemctl is-active --quiet nvidia-dcgm
error_code=$?
if [ ${error_code} -ne 0 ]
then
    echo "DCGM is inactive!"
    exit ${error_code}
fi

# to verify the installation we can query the system
# You should see a listing of all supported GPUs (and any NVSwitches) found in the system:
# dcgmi discovery -l

$COMMON_DIR/write_component_version.sh "DCGM" ${DCGM_VERSION}
