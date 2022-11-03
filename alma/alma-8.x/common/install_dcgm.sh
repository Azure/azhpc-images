#!/bin/bash
set -ex

# Install DCGM
DCGM_VERSION=2.4.4
DCGM_URL=https://azhpcstor.blob.core.windows.net/azhpc-images-store/datacenter-gpu-manager-${DCGM_VERSION}-1-x86_64.rpm
$COMMON_DIR/download_and_verify.sh $DCGM_URL "1d8fbe97797fada8048a7832bfac4bc7d3ad661bb24163d21324965ae7e7817d"
rpm -i datacenter-gpu-manager-${DCGM_VERSION}-1-x86_64.rpm
sed -i "$ s/$/ datacenter-gpu-manager/" /etc/yum.conf
rm -f datacenter-gpu-manager-${DCGM_VERSION}-1-x86_64.rpm
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
