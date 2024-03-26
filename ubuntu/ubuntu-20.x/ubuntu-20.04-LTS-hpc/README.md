# Ubuntu 20.04 HPC Image
# Intended for CX3-Pro cards

The Ubuntu 20.04 HPC Image with MOFED LTS includes optimizations and recommended configurations to deliver optimal performance,
consistency, and reliability. This image consists of the following HPC tools and libraries:

- Mellanox OFED LTS
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
- Data Center GPU Manager
- Azure HPC Diagnostics Tool

This Image is compliant with the Linux Kernel 5.4.0-1046-azure.

Software packages (MPI / HPC libraries) are configured as environment modules. Users can select preferred MPI or software packages as follows:

`module load <package-name>`

Running Single Node NCCL Test (example):

```sh
mpirun -np 4 \
    -x LD_LIBRARY_PATH \
    --allow-run-as-root \
    --map-by ppr:4:node \
    -mca coll_hcoll_enable 0 \
    -x UCX_TLS=tcp \
    -x CUDA_DEVICE_ORDER=PCI_BUS_ID \
    -x NCCL_SOCKET_IFNAME=eth0 \
    -x NCCL_DEBUG=WARN \
    /opt/nccl-tests/build/all_reduce_perf -b1K -f2 -g1 -e 4G
```