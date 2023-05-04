# SUSE Linux Enterprise HPC 15 SP4 enhanced image

SUSE Linux Enterprise HPC is a SUSE maintained and supported commercial product for the HPC market.

SUSE provides images in the Azure Marketplace as PayAsYouGo (PAYG) or BringYourOwnSubscription (BYOS) model

The SLE HPC 15 SP4 includes optimizations and recommended configurations to deliver optimal performance,
consistency, and reliability.
As an enterprise distribution, SUSE provides stable long term support and many certifications with vendors.

See documentation at https://documentation.suse.com/sle-hpc/15-SP4/

This setup here is build on top of **the PAYG image**, as it provides easy access without any registration to all SUSE provided software packages.

The azhpc-images script will in addition add modules and libraries which are NOT supported by SUSE.

SLE HPC uses Lmod as environment module.
It is required at build time and runtime of the system.
For more information, Section 7.1, “Lmod - Lua-based environment modules” within the documentation.

Many components come per default with the distribution like slurm, genders, pdsh, munge, hwloc, conman, numpy, scipy, PLlx,openblas, hdf5, openmpi, mvapich2, mpich, imb, papi, mpiP, spack, dolly, lmod, (details see documentation), but some are added as they sometimes could not be directly distributed by a Linux vendor.

All SLE HPC libraries specifically built for HPC are installed under /usr/lib/hpc.
They are not part of the standard search path, so the Lmod environment module system is required.

## Enhancements
This image consists of the following additional HPC tools and libraries:

- *(S) provided and supported by SUSE*
- *(E) external sources, added by the script - not supported by SUSE*

### Infiniband

- (S) - Mellanox OFED (inbox drivers)
- (S) - Pre-configured IPoIB (IP-over-InfiniBand)

### Popular InfiniBand based MPI Libraries

- (E) - HPC-X v.2.12
- (E) - IntelMPI (via Intel oneAPI) v2021.7.0
- (S) - MVAPICH2
- (S) - MPICH 4
- (S) - OpenMPI (v3 and v4)

### Optimized librares

- (E) - AMD (via tarball AOCL 3.1.0)
  - Blis
  - FFTW
  - Flame

- (E) - Intel MKL (Intel oneAPI via intel-oneapi-repo) v2022.2.0

- (E) - Nvida drivers 520.61
- (E) - CUDA 11.8

- (E) - Data Center GPU Manager 3.0.4
- (E) - Azure HPC Diagnostics Tool

- (S) - Docker
- (E) - NVIDIA Docker 20.10.17_ce

Software packages are configured as environment modules (lmod). Users can select preferred MPI or software packages as follows:
`module load <package-name>`
Don't forget to set the group "video" for your user running nvidia cmds

sudo usermod -a -G video <youruser>
