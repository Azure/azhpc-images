#!/bin/bash
set -ex

# Place NDv5 customizations under /opt/microsoft/ndv5
mkdir -p /opt/microsoft/ndv5

# Link the NDv5 topology file into /opt/microsoft/ndv5/
ln -sf /opt/microsoft/ndv5-topo.xml /opt/microsoft/ndv5/topo.xml

## Set NCCL configuration file for NDv5
bash -c "cat > /etc/nccl.conf" <<'EOF'
NCCL_IB_PCI_RELAXED_ORDERING=1
NCCL_TOPO_FILE=/opt/microsoft/ndv5/topo.xml
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
