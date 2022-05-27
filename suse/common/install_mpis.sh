#!/bin/bash
set -e

# MVAPICH
zypper install --no-confirm \
    mpich-gnu-hpc \
    mpich-gnu-hpc-devel

# MVAPICH2
zypper install --no-confirm \
    mvapich2-gnu-hpc \
    mvapich2-gnu-hpc-devel \
    # mvapich2-gnu-hpc-doc

# OpenMPI v3
zypper install --no-confirm \
    openmpi3-gnu-hpc \
    libopenmpi3-gnu-hpc \
    openmpi3-gnu-hpc-devel
    # openmpi3-gnu-hpc-docs

# OpenMPI v4
zypper install --no-confirm \
    openmpi4-gnu-hpc \
    libopenmpi4-gnu-hpc \
    openmpi4-gnu-hpc-devel
    # openmpi4-gnu-hpc-docs

# Setup module files for MPIs
mkdir -p /usr/share/Modules/modulefiles/mpi/

# MVAPICH2
cat << EOF >> /usr/share/Modules/modulefiles/mpi/mvapich2-${MV2_VERSION}
#%Module 1.0
#
#  MVAPICH2 ${MV2_VERSION}
#
conflict        mpi
module load ${GCC_VERSION}
prepend-path    PATH            /opt/mvapich2-${MV2_VERSION}/bin
prepend-path    LD_LIBRARY_PATH /opt/mvapich2-${MV2_VERSION}/lib
prepend-path    MANPATH         /opt/mvapich2-${MV2_VERSION}/share/man
setenv          MPI_BIN         /opt/mvapich2-${MV2_VERSION}/bin
setenv          MPI_INCLUDE     /opt/mvapich2-${MV2_VERSION}/include
setenv          MPI_LIB         /opt/mvapich2-${MV2_VERSION}/lib
setenv          MPI_MAN         /opt/mvapich2-${MV2_VERSION}/share/man
setenv          MPI_HOME        /opt/mvapich2-${MV2_VERSION}
EOF

# OpenMPI
cat << EOF >> /usr/share/Modules/modulefiles/mpi/openmpi-${OMPI_VERSION}
#%Module 1.0
#
#  OpenMPI ${OMPI_VERSION}
#
conflict        mpi
module load ${GCC_VERSION}
prepend-path    PATH            /opt/openmpi-${OMPI_VERSION}/bin
prepend-path    LD_LIBRARY_PATH /opt/openmpi-${OMPI_VERSION}/lib
prepend-path    MANPATH         /opt/openmpi-${OMPI_VERSION}/share/man
setenv          MPI_BIN         /opt/openmpi-${OMPI_VERSION}/bin
setenv          MPI_INCLUDE     /opt/openmpi-${OMPI_VERSION}/include
setenv          MPI_LIB         /opt/openmpi-${OMPI_VERSION}/lib
setenv          MPI_MAN         /opt/openmpi-${OMPI_VERSION}/share/man
setenv          MPI_HOME        /opt/openmpi-${OMPI_VERSION}
EOF

#IntelMPI-v2021
cat << EOF >> /usr/share/Modules/modulefiles/mpi/impi_${IMPI_2021_VERSION}
#%Module 1.0
#
#  Intel MPI ${IMPI_2021_VERSION}
#
conflict        mpi
module load /opt/intel/oneapi/mpi/${IMPI_2021_VERSION}/modulefiles/impi
setenv          MPI_BIN         /opt/intel/oneapi/mpi/${IMPI_2021_VERSION}/bin
setenv          MPI_INCLUDE     /opt/intel/oneapi/mpi/${IMPI_2021_VERSION}/include
setenv          MPI_LIB         /opt/intel/oneapi/mpi/${IMPI_2021_VERSION}/lib
setenv          MPI_MAN         /opt/intel/oneapi/mpi/${IMPI_2021_VERSION}/man
setenv          MPI_HOME        /opt/intel/oneapi/mpi/${IMPI_2021_VERSION}
EOF

# Create symlinks for modulefiles
ln -s /usr/share/Modules/modulefiles/mpi/mvapich2-${MV2_VERSION} /usr/share/Modules/modulefiles/mpi/mvapich2
ln -s /usr/share/Modules/modulefiles/mpi/openmpi-${OMPI_VERSION} /usr/share/Modules/modulefiles/mpi/openmpi
ln -s /usr/share/Modules/modulefiles/mpi/impi_${IMPI_2021_VERSION} /usr/share/Modules/modulefiles/mpi/impi-2021


