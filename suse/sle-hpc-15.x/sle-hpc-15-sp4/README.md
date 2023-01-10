# SUSE Linux Enterprise HPC 15 SP4 Image

SUSE Linux Enterprise HPC is a SUSE maintained commercial product for the HPC market.

SUSE provides images in the Azure Marketplace as PayAsYouGo or BringYourOwnSubscription model

The setup here is build with the PAYG image, as it provides easy access without any registration to all SUSE provided software packages.

The SLE HPC 15 SP4 includes optimizations and recommended configurations to deliver optimal performance,
consistency, and reliability.
As an enterprise distribution, we provide stable long term support and many certifications with vendors.

See documentation at https://documentation.suse.com/sle-hpc/15-SP4/

The environment module Lmod is installed for all roles.
It is required at build time and runtime of the system.
For more information, Section 7.1, “Lmod - Lua-based environment modules” within the documentation.

Many components come per default with the distribution,
but some are added like in the CentOS and Ubuntu images.

All libraries specifically built for HPC are installed under /usr/lib/hpc.
They are not part of the standard search path, so the Lmod environment module system is required.

This image consists of the following HPC tools and libraries:

- Mellanox OFED (inbox drivers)
- Pre-configured IPoIB (IP-over-InfiniBand)
- Popular InfiniBand based MPI Libraries

  - HPC-X v.2.12
  - IntelMPI (via Intel oneAPI) v2021.7.0
  - MVAPICH2
  - MPICH 4
  - OpenMPI (v3 and v4)

<!--
- Communication Runtimes
  - Libfabric
  - OpenUCX
-->
- Optimized librares

  - AMD (via tarball AOCL 3.1.0)
      Blis
      FFTW
      Flame

  - Intel MKL (Intel oneAPI via intel-oneapi-repo)
    v2022.2.0

  - Nvida drivers 520.61
  - CUDA 11.8

- Data Center GPU Manager 3.0.4
- Azure HPC Diagnostics Tool

- Docker
- NVIDIA Docker 20.10.17_ce

Software packages are configured as environment modules (lmod). Users can select preferred MPI or software packages as follows:
`module load <package-name>`

