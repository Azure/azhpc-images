#!/bin/bash
set -ex

# Place NDv6 customizations under /opt/microsoft/ndv6
mkdir -p /opt/microsoft/ndv6

## load nvidia-peermem module
## Ubuntu 26.04: skip — nvidia-peermem requires the legacy
## ib_register_peer_memory_client() symbol exported only by DOCA-OFED's
## patched ib_core, which we do not install on resolute (kernel 7.0).
## GPUDirect RDMA on inbox kernels uses the dma-buf path instead.
if . /etc/os-release && [[ "${ID}" == "ubuntu" && "${VERSION_ID}" == "26.04" ]]; then
    echo "Ubuntu 26.04 detected; skipping 'modprobe nvidia-peermem' (no DOCA-OFED)."
else
    modprobe nvidia-peermem
fi