#!/bin/bash
set -ex

# Place NCv4 topology and graph files under /opt/microsoft/ncv4
mkdir -p /opt/microsoft/ncv4

# Link the NCv4 topology and graph files into /opt/microsoft/ncv4/
ln -sf /opt/microsoft/ncv4-topo.xml /opt/microsoft/ncv4/topo.xml
ln -sf /opt/microsoft/ncv4-graph.xml /opt/microsoft/ncv4/graph.xml

## Set NCCL configuration file for NCv4
bash -c "cat > /etc/nccl.conf" <<'EOF'
NCCL_TOPO_FILE=/opt/microsoft/ncv4/topo.xml
NCCL_GRAPH_FILE=/opt/microsoft/ncv4/graph.xml
NCCL_IGNORE_CPU_AFFINITY=1
EOF

## Setup NVME devices
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
