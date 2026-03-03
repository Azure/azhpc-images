#!/bin/bash
set -ex

# Place NCv6 customizations under /opt/microsoft/ncv6
mkdir -p /opt/microsoft/ncv6

# Note: Topology file symlinks are not needed for NCv6's simple PCIe topology.
# This can be added later if needed.

## Set NCCL configuration file for NCv6
# NCv6 has 1-2 GPUs with no NVSwitch or NVLink; use standard Ethernet.
bash -c "cat > /etc/nccl.conf" <<'EOF'
NCCL_SOCKET_IFNAME=eth0
EOF
