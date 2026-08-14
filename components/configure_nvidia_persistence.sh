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
fi

# Enable unconditionally so first-boot activation works whether the unit was
# written by this script or shipped by a distro driver package.
systemctl enable nvidia-persistenced.service

# Do NOT start/restart nvidia-persistenced at build time. The daemon attaches
# to /dev/nvidia* and exits non-zero if no GPU is present, which breaks builds
# on general-purpose build SKUs (build_vm_size != target_vm_size). The unit is
# enabled above and Restart=always in its [Service] section, so it will come
# up cleanly on first boot on the customer VM. Activation is verified after
# reboot by `verify_nvidia_persistenced_service` in tests/test-definitions.sh
# (gated on actual NVIDIA GPU presence).
