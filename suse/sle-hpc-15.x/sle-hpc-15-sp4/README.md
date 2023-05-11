# SUSE Linux Enterprise HPC 15 SP4 enhanced image

SUSE Linux Enterprise HPC is a SUSE maintained and supported commercial product for the HPC market.
see https://www.suse.com/products/server/hpc/

SUSE provides images in the Azure Marketplace as PayAsYouGo (PAYG) or BringYourOwnSubscription (BYOS) model

The SLE HPC 15 SP4 includes optimizations and recommended configurations to deliver optimal performance,
consistency, and reliability. As an enterprise distribution, SUSE provides stable long term support and many certifications with vendors.

Many components come per default with the distribution like slurm, genders, pdsh, munge, hwloc, conman, numpy, scipy, PLlx,openblas, hdf5, openmpi, mvapich2, mpich, imb, papi, mpiP, spack, dolly, lmod.

See documentation at https://documentation.suse.com/sle-hpc/15-SP4/

This setup here is build on top of **the PAYG image**, as it provides easy access without any registration to all SUSE provided software packages.

The azhpc-images script will in addition add modules and libraries which are NOT supported by SUSE and could not delivered by SUSE. You need to own the subscriptions/licences and agree to the respective EULAs from the vendors by yourself.

## Enhancements
This image consists of the following additional HPC tools and libraries:

- *(S) provided and supported by SUSE*
- *(E) external sources, added by the script - not supported by SUSE*

### Infiniband

- (S) - Mellanox OFED (inbox drivers)
- (S) - Pre-configured IPoIB (IP-over-InfiniBand)

### Popular InfiniBand based MPI Libraries

- (E) - HPC-X
- (E) - IntelMPI (via Intel oneAPI)
- (S) - MVAPICH2
- (S) - MPICH 4
- (S) - OpenMPI (v3 and v4)

### Optimized librares

- (E) - AMD (via tarball AOCL )
  - Blis
  - FFTW
  - Flame

- (E) - Intel MKL (Intel oneAPI via intel-oneapi-repo)

- (E) - Nvida drivers
- (E) - CUDA
- (E) - NCCL

- (E) - Data Center GPU Manager
- (E) - Azure HPC Diagnostics Tool

- (S) - Docker
- (E) - NVIDIA Docker

Software packages are configured as environment modules (lmod). Users can select preferred MPI or software packages as follows:
`module load <package-name>`

Don't forget to set the group "video" for your user running nvidia cmds

`sudo usermod -a -G video <youruser>`
