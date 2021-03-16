# CentOS 8.3 HPC Image

The CentOS 8.3 HPC Image includes optimizations and recommended configurations to deliver optimal performance,
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
- Azure HPC Diagnostics Tool

Software packages are configured as environment modules. Users can select preferred MPI or software packages as follows:

`module load <package-name>`
