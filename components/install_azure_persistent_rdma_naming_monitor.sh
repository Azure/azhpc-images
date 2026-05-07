#!/bin/bash
set -ex

#
# setup systemd service
#

cat <<EOF >/usr/sbin/azure_persistent_rdma_naming_monitor.sh
#!/bin/bash

# monitoring service to check that hca_id's are named correctly
# if incorrect, restart azure_persistent_rdma_naming.service
#
# Devices are enumerated directly from sysfs so this works on distros without
# the Mellanox/DOCA-OFED \`ibdev2netdev\` helper (e.g. Ubuntu 26.04 inbox
# rdma-core).

while true; do

    shopt -s nullglob
    ib_devices=( /sys/class/infiniband/* )
    shopt -u nullglob

    for ibpath in "\${ib_devices[@]}"; do

        device=\$(basename "\$ibpath")

        if [[ \$device != *"an"* && \$device != *"ib"* ]]; then
            systemctl enable azure_persistent_rdma_naming.service
            systemctl restart azure_persistent_rdma_naming.service
            sleep 60
            break
        fi

    done

    sleep 60

done
EOF
chmod 755 /usr/sbin/azure_persistent_rdma_naming_monitor.sh

cat <<EOF >/etc/systemd/system/azure_persistent_rdma_naming_monitor.service
[Unit]
Description=Azure persistent RDMA naming Monitor
After=network.target systemd-udev-settle.service azure_persistent_rdma_naming.service
Wants=systemd-udev-settle.service

[Service]
Type=simple
ExecStart=/usr/sbin/azure_persistent_rdma_naming_monitor.sh
RemainAfterExit=true
StandardOutput=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl enable azure_persistent_rdma_naming_monitor.service
systemctl start azure_persistent_rdma_naming_monitor.service
