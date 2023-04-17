#!/bin/bash
set -ex

# Place NDv5 customizations under /opt/microsoft/ndv5
mkdir -p /opt/microsoft/ndv5

## Set NCCL configuration file for NDv5
bash -c "cat > /etc/nccl.conf" <<'EOF'
NCCL_IB_PCI_RELAXED_ORDERING=1
EOF

## NVIDIA Fabric manager
systemctl enable nvidia-fabricmanager
systemctl start nvidia-fabricmanager
systemctl is-active --quiet nvidia-fabricmanager

error_code=$?
if [ ${error_code} -ne 0 ]
then
    echo "NVIDIA Fabic Manager Inactive!"
    exit ${error_code}
fi

## load nvidia-peermem module
modprobe nvidia-peermem

# ## Setup NVME devices
# if [ ! -f /etc/systemd/system/nvme-raid.service ]; then
#     /opt/azurehpc/customizations/setup_nvme.sh
# fi

# ## NVME raid service
# systemctl enable nvme-raid
# systemctl start nvme-raid
# systemctl is-active --quiet nvme-raid

# error_code=$?
# if [ ${error_code} -ne 0 ]
# then
#     echo "Failed to setup/ mount NVMe devices!"
#     exit ${error_code}
# fi
