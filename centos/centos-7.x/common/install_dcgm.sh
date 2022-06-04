#!/bin/bash
set -ex

# Install DCGM
DCGM_VERSION=2.3.1
$COMMON_DIR/write_component_version.sh "DCGM" ${DCGM_VERSION}
DCGM_URL=https://developer.download.nvidia.com/compute/cuda/repos/rhel7/x86_64/datacenter-gpu-manager-${DCGM_VERSION}-1-x86_64.rpm
$COMMON_DIR/download_and_verify.sh $DCGM_URL "586bf03a7b0c9827c80dc0a82c6e8fe780ff1d76d82b103866906e4cdd191710"
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
