#!/bin/bash
set -ex

# Place NDv2 topology file under /opt/microsoft/ndv2
mkdir -p /opt/microsoft/ndv2

# Link the NDv2 topology file into /opt/microsoft/ndv2/
ln -sf /opt/microsoft/ndv2-topo.xml /opt/microsoft/ndv2/topo.xml

## Set NCCL configuration file for NDv2
bash -c "cat > /etc/nccl.conf" <<'EOF'
NCCL_TOPO_FILE=/opt/microsoft/ndv2/topo.xml
NCCL_IGNORE_CPU_AFFINITY=1
EOF
