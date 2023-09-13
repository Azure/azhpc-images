#!/bin/bash
set -ex

#
# setup systemd service
#

cat <<EOF >/usr/sbin/azure_persistent_rdma_naming_monitor.sh
#!/bin/bash

# monitoring service to check that hca_id's are named correctly
# if incorrect, restart azure_persistent_rdma_naming.service

while true; do 

    for device in \$(ibdev2netdev -v | sort -n | cut -f2 -d' '); do
        
        link_layer=\$(ibv_devinfo -d \$device | sed -n 's/^[\ \t]*link_layer:[\ \t]*\([a-zA-Z]*\)\$/\1/p')

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
After=network.target

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
