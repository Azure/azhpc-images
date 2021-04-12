# CentOS 7.9 HPC Image

The CentOS 7.9 HPC Image includes optimizations and recommended configurations to deliver optimal performance,
consistency, and reliability. This image consists of the following HPC tools and libraries:

- Mellanox OFED
- Pre-configured IPoIB (IP-over-InfiniBand)
- Popular InfiniBand based MPI Libraries
  - HPC-X
  - IntelMPI
  - MVAPICH2
  - OpenMPI
- Communication Runtimes
  - Libfabric
  - OpenUCX
- Optimized librares
  - AMD Blis
  - AMD FFTW
  - AMD Flame
  - Intel MKL
- GPU Drivers
  - Nvidia GPU Driver
- NCCL
  - NCCL RDMA Sharp Plugin
  - NCCL Tests
- NV Peer Memory (GPU Direct RDMA)
- GRD Copy
- Data Center GPU Manager
- Azure HPC Diagnostics Tool

Software packages are configured as environment modules. Users can select preferred MPI or software packages as follows:

`module load <package-name>`
