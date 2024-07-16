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
EOF

