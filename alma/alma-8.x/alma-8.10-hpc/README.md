# AlmaLinux 8.10 HPC Image

The AlmaLInux 8.10 HPC Image includes optimizations and recommended configurations to deliver optimal performance,
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
- GDRCopy
- Data Center GPU Manager
- Azure HPC Diagnostics Tool
- Moby
- NVIDIA-Docker
- Moneo (Distributed HPC/AI system monitor)

This Image is compliant with the Linux Kernel 4.18.0-425.3.1.el8.x86_64

Software packages are configured as environment modules. Users can select preferred MPI or software packages as follows:

`module load <package-name>`
