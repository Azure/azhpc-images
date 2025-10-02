#!/bin/bash
set -ex

sed -i '/\[main\]/a no-auto-default=*' /etc/NetworkManager/NetworkManager.conf

# update network config on reboot
mkdir -p /lib/systemd/system/cloud-init-local.service.d/
cat <<EOF > /lib/systemd/system/cloud-init-local.service.d/50-azure-clear-persistent-obj-pkl.conf
[Service]
ExecStartPre=-/bin/sh -xc 'if [ -e /var/lib/cloud/instance/obj.pkl ]; then echo "cleaning persistent cloud-init object"; rm /var/lib/cloud/instance/obj.pkl; fi; exit 0'
EOF
