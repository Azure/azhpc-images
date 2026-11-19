#!/bin/bash
set -ex

# Disable Cloud-Init
if [[ $DISTRIBUTION == *"almalinux"* ]] || [[ $DISTRIBUTION == *"rocky"* ]] || [[ $DISTRIBUTION == *"rhel"* ]]; then
    cat << EOF >> /etc/cloud/cloud.cfg.d/99-custom-networking.cfg
network: {config: disabled}
EOF

    # Remove Hardware Mac Address and DHCP Name
    # EL10 NetworkManager has no ifcfg support, so the file may not exist.
    if [[ -f /etc/sysconfig/network-scripts/ifcfg-eth0 ]]; then
        sed -i '/^HWADDR=.*$/d' /etc/sysconfig/network-scripts/ifcfg-eth0
        sed -i '/^DHCP_HOSTNAME=.*$/d' /etc/sysconfig/network-scripts/ifcfg-eth0
        sed -i '/^IPV6INIT=.*$/d' /etc/sysconfig/network-scripts/ifcfg-eth0
    fi

    # EL10 uses NetworkManager keyfiles, and cloud-init's eth0 keyfile pins the
    # build VM's MAC. With cloud-init networking disabled and no-auto-default=*,
    # VMs created from the image would get no network, so match eth0 by name.
    if [[ $DISTRIBUTION =~ ^(almalinux|rocky|rhel)10 ]]; then
        eth0_mac=$(cat /sys/class/net/eth0/address 2>/dev/null || true)
        for kf in /etc/NetworkManager/system-connections/*.nmconnection; do
            [[ -f "$kf" ]] || continue
            if ! grep -qx 'interface-name=eth0' "$kf" && \
               ! { [[ -n "$eth0_mac" ]] && grep -qix "mac-address=${eth0_mac}" "$kf"; }; then
                continue
            fi
            sed -i '/^mac-address=/d; /^dhcp-hostname=/d' "$kf"
            grep -q '^interface-name=' "$kf" || sed -i '/^\[connection\]/a interface-name=eth0' "$kf"
        done
        nmcli connection reload
    fi

    if [[ $DISTRIBUTION == "almalinux8.10" ]] || [[ $DISTRIBUTION == "rocky8.10" ]] || [[ $DISTRIBUTION == rhel8* ]]; then
        SCRIPT_PATH="/usr/sbin/disable_cloudinit.sh"
        SERVICE_PATH="/etc/systemd/system/disable_cloudinit.service"
        IFCFG_FILE="/etc/sysconfig/network-scripts/ifcfg-eth0"

        # Cloud init keeps reverting the changes /etc/sysconfig/network-scripts/ifcfg-eth0 even though it is disabled
        cat << EOF > "$SCRIPT_PATH"
#!/bin/bash

# Remove Hardware Mac Address and DHCP Name
sed -i '/^HWADDR=.*$/d' "$IFCFG_FILE"
sed -i '/^DHCP_HOSTNAME=.*$/d' "$IFCFG_FILE"
sed -i '/^IPV6INIT=.*$/d' "$IFCFG_FILE"

# Restart NetworkManager to apply changes
systemctl restart NetworkManager
EOF
        chmod 755 "$SCRIPT_PATH"
        cat << EOF > "$SERVICE_PATH"
[Unit]
Description=Clean network config after boot
After=network.target NetworkManager.service
Wants=NetworkManager.service

[Service]
Type=oneshot
ExecStart=$SCRIPT_PATH
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload
        systemctl enable disable_cloudinit.service
        systemctl start disable_cloudinit.service
        systemctl is-active --quiet disable_cloudinit.service
        error_code=$?
        if [ ${error_code} -ne 0 ]
        then
            echo "Disable Cloud Init service Inactive!"
            exit ${error_code}
        fi
    fi
else
    echo network: {config: disabled} | sudo tee /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg
    if [[ "${TARGET_NODE_TYPE:-azure_vm_regular}" == "baremetal_1p" ]]; then
        bash -c "cat > /etc/netplan/net.yaml" <<'EOF'
network:
  ethernets:
    mana-nics:
      dhcp4: true
      match:
        driver: mana
        name: e*
    eth0:
      dhcp4: true
EOF

        chmod 600 /etc/netplan/net.yaml
        # Delete the default cloud-init network config
        if [ -f /etc/netplan/50-cloud-init.yaml ]; then
            rm /etc/netplan/50-cloud-init.yaml
        fi
        touch /etc/cloud/cloud-init.disabled
    else
        bash -c "cat > /etc/netplan/50-cloud-init.yaml" <<'EOF'
network:
    ethernets:
        eth0:
            dhcp4: true
    version: 2
EOF
        netplan apply
    fi
fi
