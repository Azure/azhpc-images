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

## Ubuntu 26.04: skip — nvidia-peermem requires the legacy
## ib_register_peer_memory_client() symbol exported only by DOCA-OFED's
## patched ib_core, which we do not install on resolute (kernel 7.0).
## GPUDirect RDMA on inbox kernels uses the dma-buf path instead.
if . /etc/os-release && [[ "${ID}" == "ubuntu" && "${VERSION_ID}" == "26.04" ]]; then
    echo "Ubuntu 26.04 detected; skipping 'modprobe nvidia-peermem' (no DOCA-OFED)."
else
    modprobe nvidia-peermem
fi