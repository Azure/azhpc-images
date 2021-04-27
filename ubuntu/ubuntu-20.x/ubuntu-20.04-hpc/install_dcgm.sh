#!/bin/bash
set -ex

# Install DCGM
DCGM_VERSION=2.1.7
DCGM_GPUMNGR_URL=https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/datacenter-gpu-manager_${DCGM_VERSION}_amd64.deb
$COMMON_DIR/download_and_verify.sh $DCGM_GPUMNGR_URL "c55591b3f8ce66dc6215f1f40c6e7debdd557469ad911532642fd8622124e08f"
dpkg -i datacenter-gpu-manager_*.deb && \
rm -f datacenter-gpu-manager_*.deb

# Create service for dcgm to launch on bootup
bash -c "cat > /etc/systemd/system/dcgm.service" <<'EOF'
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

systemctl enable dcgm
systemctl start dcgm
