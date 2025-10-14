#!/bin/bash
set -ex

# Disable Cloud-Init
if [[ $DISTRIBUTION == *"almalinux"* ]]; then
    cat << EOF >> /etc/cloud/cloud.cfg.d/99-custom-networking.cfg
network: {config: disabled}
EOF

    # Remove Hardware Mac Address and DHCP Name
    sed -i '/^HWADDR=.*$/d' /etc/sysconfig/network-scripts/ifcfg-eth0 
    sed -i '/^DHCP_HOSTNAME=.*$/d' /etc/sysconfig/network-scripts/ifcfg-eth0 
    sed -i '/^IPV6INIT=.*$/d' /etc/sysconfig/network-scripts/ifcfg-eth0 

    if [[ $DISTRIBUTION == "almalinux8.10" ]]; then
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
    fi
else
    echo network: {config: disabled} | sudo tee /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg
    bash -c "cat > /etc/netplan/50-cloud-init.yaml" <<'EOF'
network:
    ethernets:
        eth0:
            dhcp4: true
    version: 2
EOF
    netplan apply
fi
