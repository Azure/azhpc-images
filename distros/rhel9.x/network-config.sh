#!/bin/bash
set -ex

# Sorts after NetworkManager-config-server's 00-server.conf, so this value wins.
cat <<EOF > /etc/NetworkManager/conf.d/99-azurehpc-no-auto-default.conf
[main]
no-auto-default=type:infiniband
EOF

# update network config on reboot
mkdir -p /lib/systemd/system/cloud-init-local.service.d/
cat <<EOF > /lib/systemd/system/cloud-init-local.service.d/50-azure-clear-persistent-obj-pkl.conf
[Service]
ExecStartPre=-/bin/sh -xc 'if [ -e /var/lib/cloud/instance/obj.pkl ]; then echo "cleaning persistent cloud-init object"; rm /var/lib/cloud/instance/obj.pkl; fi; exit 0'
EOF
