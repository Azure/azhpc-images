#!/bin/bash
set -ex

# Parameter
# Ubuntu Version
VERSION=$1

# Install DCGM
DCGM_VERSION=2.4.4
DCGM_GPUMNGR_URL=https://azhpcstor.blob.core.windows.net/azhpc-images-store/datacenter-gpu-manager_${DCGM_VERSION}_amd64.deb
$COMMON_DIR/download_and_verify.sh $DCGM_GPUMNGR_URL "69ba98bbc4f657f6a15a2922aee0ea6b495fad49147d056a8f442c531b885e0e"
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
