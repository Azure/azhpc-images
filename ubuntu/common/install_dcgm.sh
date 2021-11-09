#!/bin/bash
set -ex

# Parameter
# Ubuntu Version
VERSION=$1

# Install DCGM
DCGM_VERSION=2.3.1
$COMMON_DIR/write_component_version.sh "DCGM" ${DCGM_VERSION}
DCGM_GPUMNGR_URL=https://developer.download.nvidia.com/compute/cuda/repos/ubuntu${VERSION}/x86_64/datacenter-gpu-manager_${DCGM_VERSION}_amd64.deb
$COMMON_DIR/download_and_verify.sh $DCGM_GPUMNGR_URL "0431dc987d3e67e6193b47c40ce71be443069c49adaa91ea0b904629b594a12c"
dpkg -i datacenter-gpu-manager_${DCGM_VERSION}_amd64.deb && \
rm -f datacenter-gpu-manager_${DCGM_VERSION}_amd64.deb

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
