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

# Ensure NVIDIA Fabric Manager is active
retries=0
while ! systemctl is-active --quiet nvidia-fabricmanager; do
    error_code=$?
    if (( retries++ >= 5 )); then
        echo "NVIDIA Fabic Manager Inactive!"
        exit ${error_code}
    fi
    echo "Waiting for NVIDIA Fabric Manager..."
    sleep 5
done
echo "NVIDIA Fabric Manager is active."

## load nvidia-peermem module
modprobe nvidia-peermem

