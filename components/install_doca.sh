#!/bin/bash
set -ex

source ${UTILS_DIR}/utilities.sh

if [[ "${DISTRIBUTION}" == "ubuntu26.04" ]]; then
    DOCA_VERSION="3.4.0"
    DOCA_URL="https://linux.mellanox.com/public/repo/doca/${DOCA_VERSION}/ubuntu26.04/x86_64/"

    apt-get update
    apt-get install -y ca-certificates curl gnupg
    curl -fsSL https://linux.mellanox.com/public/repo/doca/GPG-KEY-Mellanox.pub \
        | gpg --dearmor --yes -o /etc/apt/trusted.gpg.d/GPG-KEY-Mellanox.pub
    echo "deb [signed-by=/etc/apt/trusted.gpg.d/GPG-KEY-Mellanox.pub] ${DOCA_URL} ./" > /etc/apt/sources.list.d/doca.list

    apt-get update
    apt-get upgrade -y
    apt-get -y install doca-ofed
elif [[ $DISTRIBUTION == *"ubuntu"* ]]; then
    doca_metadata=$(get_component_config "doca")
    DOCA_VERSION=$(jq -r '.version' <<< $doca_metadata)
    DOCA_SHA256=$(jq -r '.sha256' <<< $doca_metadata)
    DOCA_URL=$(jq -r '.url' <<< $doca_metadata)
    DOCA_FILE=$(basename ${DOCA_URL})

    download_and_verify $DOCA_URL $DOCA_SHA256
    dpkg -i $DOCA_FILE

    apt-get update
    apt-get upgrade -y
    apt-get -y install doca-ofed
elif [[ $DISTRIBUTION == "azurelinux3.0" ]]; then
    doca_metadata=$(get_component_config "doca")
    DOCA_VERSION=$(jq -r '.version' <<< $doca_metadata)
    DOCA_SHA256=$(jq -r '.sha256' <<< $doca_metadata)
    DOCA_URL=$(jq -r '.url' <<< $doca_metadata)
    DOCA_FILE=$(basename ${DOCA_URL})

    download_and_verify $DOCA_URL $DOCA_SHA256
    rpm -i $DOCA_FILE
    dnf clean all
    dnf install -y doca-extra
    /opt/mellanox/doca/tools/doca-kernel-support
    dnf install -y doca-ofed-userspace
    dnf -y install doca-ofed
else
    doca_metadata=$(get_component_config "doca")
    DOCA_VERSION=$(jq -r '.version' <<< $doca_metadata)
    DOCA_SHA256=$(jq -r '.sha256' <<< $doca_metadata)
    DOCA_URL=$(jq -r '.url' <<< $doca_metadata)
    DOCA_FILE=$(basename ${DOCA_URL})

    download_and_verify $DOCA_URL $DOCA_SHA256
    # RHEL-family: AlmaLinux, Rocky Linux, RHEL, etc.
    rpm -i $DOCA_FILE
    dnf clean all
    
    # Install DOCA extras for compatibility
    dnf install -y doca-extra
    
    /opt/mellanox/doca/tools/doca-kernel-support
    FINAL_REPO_FILE=$(find /tmp/DOCA.*/ -name 'doca-kernel-repo-*.rpm' -printf '%T@ %p\n' | sort -n | tail -1 | cut -d' ' -f2-)
    rpm -i $FINAL_REPO_FILE
    # Backup
    cp /etc/dnf/dnf.conf /etc/dnf/dnf.conf.bak
    sed -i '/^exclude=/d' /etc/dnf/dnf.conf
    dnf -y install doca-ofed-userspace
    dnf -y install doca-ofed
    # Restore exclusion
    mv /etc/dnf/dnf.conf.bak /etc/dnf/dnf.conf
fi

write_component_version "DOCA" $DOCA_VERSION
OFED_VERSION=$(ofed_info | sed -n '1,1p' | awk -F'-' 'OFS="-" {print $3,$4}' | tr -d ':')
write_component_version "OFED" $OFED_VERSION

# Create systemd drop-in configuration for openibd.service
# This adds restart on failure and ensures it starts after udev settles
mkdir -p /etc/systemd/system/openibd.service.d
cat > /etc/systemd/system/openibd.service.d/override.conf <<EOF
[Unit]
After=systemd-udev-settle.service
Wants=systemd-udev-settle.service

[Service]
Restart=on-failure
RestartSec=5
EOF

if [[ "${NODE_TYPE:-azure-vm}" == "baremetal" ]]; then
    echo -e "\n# Load IPoIB\nIPOIB_LOAD=no" | sudo tee -a /etc/infiniband/openib.conf
fi

systemctl daemon-reload
systemctl enable openibd

/etc/init.d/openibd restart
/etc/init.d/openibd status
error_code=$?
if [ ${error_code} -ne 0 ]
then
    echo "OpenIBD not loaded correctly!"
    exit ${error_code}
fi
