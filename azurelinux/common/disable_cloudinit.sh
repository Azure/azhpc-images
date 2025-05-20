#!/bin/bash
set -ex

# Disable cloud-init
echo network: {config: disabled} | sudo tee /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg
bash -c "cat > /etc/netplan/50-cloud-init.yaml" <<'EOF'
network:
    ethernets:
        eth0:
            dhcp4: true
    version: 2
EOF
netplan apply
