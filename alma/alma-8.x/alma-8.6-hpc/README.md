# AlmaLinux 8.6 HPC Image

The AlmaLInux 8.6 HPC Image includes optimizations and recommended configurations to deliver optimal performance,
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

Software packages are configured as environment modules. Users can select preferred MPI or software packages as follows:

`module load <package-name>`

## Azure Managed Lustre
Users that wish to use [Azure Managed Lustre Filesystem](https://learn.microsoft.com/en-us/azure/azure-managed-lustre/amlfs-overview) offering on virtual machine images with the following Azure Marketplace URN: `almalinux:almalinux-hpc:8_6-hpc-gen2:xxxxx` will need to install the amlfs client.<br>

Please refer to [Install client software for Red Hat Enterprise Linux, CentOS Linux, or AlmaLinux 8](https://learn.microsoft.com/en-us/azure/azure-managed-lustre/install-rhel-8), but use the following command to install instead of the one provided in step 3:
```shell
sudo dnf install --disableexcludes=main amlfs-lustre-client-2.15.1_24_gbaa21ca-$(uname -r | sed -e "s/\.$(uname -p)$//" | sed -re 's/[-_]/\./g')-1
```
