#!/bin/bash
set -ex

# Install Dependencies
pip3 install -U netifaces
pip3 install -U PyYAML

# Disable some unneeded services by default (administrators can re-enable if desired)
systemctl disable ufw

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

$COMMON_DIR/hpc-tuning.sh

# Azure Linux Agent
$UBUNTU_COMMON_DIR/install_waagent.sh
