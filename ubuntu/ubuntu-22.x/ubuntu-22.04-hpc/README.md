# Ubuntu 22.04 HPC Image

The Ubuntu 22.04 HPC Image includes optimizations and recommended configurations to deliver optimal performance, consistency, and reliability. This image consists of the following HPC tools and libraries:

- Mellanox OFED
- Pre-configured IPoIB (IP-over-InfiniBand)
- Popular InfiniBand based MPI Libraries
  - HPC-X
  - IntelMPI
  - MVAPICH2
- Communication Runtimes
  - Libfabric
  - OpenUCX
- Optimized librares
  - Intel MKL
- GPU Drivers
  - Nvidia GPU Driver
- SHARP Daemon (sharpd)
- NCCL
  - NCCL RDMA Sharp Plugin
  - NCCL Benchmarks
  - Topology file for NDv4
- NV Peer Memory (GPU Direct RDMA)
- GDR Copy
- Data Center GPU Manager
- Azure HPC Diagnostics Tool
- Moby
- NVIDIA-Docker
- Moneo (Distributed HPC/AI system monitor)

This Image is compliant with the Linux Kernel 5.15.0-1037-azure.

Software packages (MPI / HPC libraries) are configured as environment modules. Users can select preferred MPI or software packages as follows:

`module load <package-name>`

Running Single Node NCCL Test (example):

```sh
mpirun -np 8 \
    --allow-run-as-root \
    --bind-to numa --report-bindings \
    --map-by ppr:8:node \
    -x LD_LIBRARY_PATH=/usr/local/nccl-rdma-sharp-plugins/lib:$LD_LIBRARY_PATH \
    -mca coll_hcoll_enable 0 \
    -x UCX_TLS=tcp \
    -x UCX_NET_DEVICES=eth0 \
    -x CUDA_DEVICE_ORDER=PCI_BUS_ID \
    -x NCCL_SOCKET_IFNAME=eth0 \
    -x NCCL_DEBUG=WARN \
    /opt/nccl-tests/build/all_reduce_perf -b1K -f2 -g1 -e 4G
```
