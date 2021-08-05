#!/bin/bash
set -ex

# Install DCGM
DCGM_VERSION=2.1.7
$COMMON_DIR/write_component_version.sh "DCGM" ${DCGM_VERSION}
DCGM_URL=https://developer.download.nvidia.com/compute/cuda/repos/rhel7/x86_64/datacenter-gpu-manager-${DCGM_VERSION}-1-x86_64.rpm
$COMMON_DIR/download_and_verify.sh $DCGM_URL "5ba9f19805c372d7cc7cdc4e12178c0c36894c58bf8749001724db0a435ee7a2"
sudo rpm -i datacenter-gpu-manager-${DCGM_VERSION}-1-x86_64.rpm
sudo rm -f datacenter-gpu-manager-${DCGM_VERSION}-1-x86_64.rpm

# Create service for dcgm to launch on bootup
sudo bash -c "cat > /etc/systemd/system/dcgm.service" <<'EOF'
[Unit]
Description=DCGM service

[Service]
User=root
PrivateTmp=false
ExecStart=/usr/bin/nv-hostengine -n
Restart=on-abort

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable dcgm
sudo systemctl start dcgm
