#!/bin/bash
set -ex

# Disable Cloud-Init
if [[ $DISTRIBUTION == "almalinux8.10" ]]; then
    cat << EOF >> /etc/cloud/cloud.cfg.d/99-custom-networking.cfg
network: {config: disabled}
EOF

    # Remove Hardware Mac Address and DHCP Name
    sed -i '/^HWADDR=.*$/d' /etc/sysconfig/network-scripts/ifcfg-eth0 
    sed -i '/^DHCP_HOSTNAME=.*$/d' /etc/sysconfig/network-scripts/ifcfg-eth0 
    sed -i '/^IPV6INIT=.*$/d' /etc/sysconfig/network-scripts/ifcfg-eth0 
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
