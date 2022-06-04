#!/bin/bash
set -ex

# Parameter
# Ubuntu Version
VERSION=$1

# Install DCGM
DCGM_VERSION=2.3.6
DCGM_GPUMNGR_URL=https://developer.download.nvidia.com/compute/cuda/repos/ubuntu${VERSION}/x86_64/datacenter-gpu-manager_${DCGM_VERSION}_amd64.deb
$COMMON_DIR/download_and_verify.sh $DCGM_GPUMNGR_URL "d43955818b37fa80744eff75b84b71cc4c43c22a024cecfe9cbc3dc279705a6e"
dpkg -i datacenter-gpu-manager_${DCGM_VERSION}_amd64.deb && \
rm -f datacenter-gpu-manager_${DCGM_VERSION}_amd64.deb
$COMMON_DIR/write_component_version.sh "DCGM" ${DCGM_VERSION}

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
