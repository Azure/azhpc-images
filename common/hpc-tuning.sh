#!/bin/bash
set -ex

# Update memory limits
cat << EOF >> /etc/security/limits.conf
*               hard    memlock         unlimited
*               soft    memlock         unlimited
*               hard    nofile          65535
*               soft    nofile          65535
*               hard    stack           unlimited
*               soft    stack           unlimited
EOF

# Enable reclaim mode
echo "vm.zone_reclaim_mode = 1" >> /etc/sysctl.conf
echo "net.ipv4.neigh.default.gc_thresh1 = 4096" >> /etc/sysctl.conf
echo "net.ipv4.neigh.default.gc_thresh2 = 8192" >> /etc/sysctl.conf
echo "net.ipv4.neigh.default.gc_thresh3 = 16384" >> /etc/sysctl.conf
echo "sunrpc.tcp_max_slot_table_entries = 128" >> /etc/sysctl.conf

## Systemd service for starting sunrpc and adding setting parameters
cat <<EOF >/usr/sbin/sunrpc_tcp_settings.sh
#!/bin/bash

modprobe sunrpc
sysctl -p
EOF

chmod 755 /usr/sbin/sunrpc_tcp_settings.sh

cat <<EOF >/etc/systemd/system/sunrpc_tcp_settings.service
[Unit]
Description=Set sunrpc tcp settings

[Service]
User=root
Type=oneshot
ExecStart=/usr/sbin/sunrpc_tcp_settings.sh
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF

systemctl enable sunrpc_tcp_settings
systemctl start sunrpc_tcp_settings
systemctl is-active --quiet sunrpc_tcp_settings

error_code=$?
if [ ${error_code} -ne 0 ]
then
    echo "sunrpc_tcp_settings service inactive!"
    exit ${error_code}
fi

# Setting Linux NFS read-ahead limits
# Reference: 
#    https://learn.microsoft.com/en-us/azure/azure-netapp-files/performance-linux-nfs-read-ahead
#    https://learn.microsoft.com/en-us/azure/storage/blobs/secure-file-transfer-protocol-support-how-to?tabs=azure-portal
cat > /etc/udev/rules.d/90-nfs-readahead.rules <<EOM
SUBSYSTEM=="bdi", \
ACTION=="add", \
PROGRAM="/usr/bin/awk -v bdi=\$kernel 'BEGIN{ret=1} {if (\$4 == bdi) {ret=0}} END{exit ret}' /proc/fs/nfsfs/volumes", \
ATTR{read_ahead_kb}="15380"
EOM

udevadm control --reload
