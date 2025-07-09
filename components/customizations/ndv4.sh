#!/bin/bash
set -ex

# Place NDv4 topo file under /opt/microsoft/ndv4
mkdir -p /opt/microsoft/ndv4

# Link the NDv4 topology file into /opt/microsoft/ndv4/
ln -sf /opt/microsoft/ndv4-topo.xml /opt/microsoft/ndv4/topo.xml

## Set NCCL configuration file for NDv4
bash -c "cat > /etc/nccl.conf" <<'EOF'
NCCL_IB_PCI_RELAXED_ORDERING=1
NCCL_TOPO_FILE=/opt/microsoft/ndv4/topo.xml
NCCL_IGNORE_CPU_AFFINITY=1
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

