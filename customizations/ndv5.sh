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
DISTRIBUTION=$(. /etc/os-release;echo $ID$VERSION_ID)
if [[ $DISTRIBUTION != "azurelinux3.0"]]; then
    modprobe nvidia-peermem
fi