#!/bin/bash
set -ex

# Configure NVIDIA persistence daemon to keep the GPU driver loaded in memory
# This eliminates cold start delays when launching GPU applications

# Create systemd service file if it doesn't exist
if [ ! -f /etc/systemd/system/nvidia-persistenced.service ]; then
    cat <<EOF > /etc/systemd/system/nvidia-persistenced.service
[Unit]
Description=NVIDIA Persistence Daemon
Wants=syslog.target
 
[Service]
Type=forking
PIDFile=/var/run/nvidia-persistenced/nvidia-persistenced.pid
Restart=always
ExecStart=/usr/bin/nvidia-persistenced --verbose --persistence-mode
ExecStopPost=/bin/rm -rf /var/run/nvidia-persistenced
 
[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable nvidia-persistenced.service
fi

systemctl restart nvidia-persistenced.service
systemctl status nvidia-persistenced.service
if ! systemctl is-active --quiet nvidia-persistenced.service; then
    echo "nvidia-persistenced service is not running. Exiting."
    exit 1
fi
