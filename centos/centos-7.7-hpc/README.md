# CentOS 7.7 HPC Image

The CentOS 7.7 HPC Image includes optimizations and recommended configurations to deliver optimal performance,
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

The MPI libraries are configured as environment modules. Users can select any preferred MPI flavor as follows:

`module load mpi/<mpi-flavor>`
