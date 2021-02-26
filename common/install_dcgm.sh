#!/bin/bash

# Install DCGM
DCGM_VERSION=2.0.10
DCGM_GPUMNGR_URL=https://developer.download.nvidia.com/compute/redist/dcgm/${DCGM_VERSION}/DEBS/datacenter-gpu-manager_${DCGM_VERSION}_amd64.deb
$COMMON_DIR/download_and_verify.sh $DCGM_GPUMNGR_URL "c32f2758611cc4e4e2ae69372a350bf14733d92b9cb5963ada9df0ee0aa63b76"
sudo dpkg -i datacenter-gpu-manager_*.deb && \
sudo rm -f datacenter-gpu-manager_*.deb

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