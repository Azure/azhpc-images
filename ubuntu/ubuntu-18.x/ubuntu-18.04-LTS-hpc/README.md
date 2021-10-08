# Ubuntu 18.04 HPC Image
# Intended for CX3-Pro cards

The Ubuntu 18.04 HPC Image with MOFED LTS includes optimizations and recommended configurations to deliver optimal performance,
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
  - AMD Blis
  - AMD FFTW
  - AMD Flame
  - Intel MKL
- GPU Drivers
  - Nvidia GPU Driver
- Data Center GPU Manager
- Azure HPC Diagnostics Tool

This Image is compliant with the Linux Kernel 5.4.0-1043-azure.

Software packages (MPI / HPC libraries) are configured as environment modules. Users can select preferred MPI or software packages as follows:

`module load <package-name>`
