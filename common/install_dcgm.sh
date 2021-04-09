#!/bin/bash

# Install DCGM
DCGM_VERSION=2.1.4
DCGM_GPUMNGR_URL=https://developer.download.nvidia.com/compute/redist/dcgm/${DCGM_VERSION}/DEBS/datacenter-gpu-manager_${DCGM_VERSION}_amd64.deb
$COMMON_DIR/download_and_verify.sh $DCGM_GPUMNGR_URL "eac676359ce6ba6682b480fca00e74c6526c2c01421c345f2452857d84de2daa"
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
