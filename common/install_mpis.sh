#!/bin/bash

GCC_VERSION=$1
HPCX_PATH=$2

HCOLL_PATH=${HPCX_PATH}/hcoll
UCX_PATH=${HPCX_PATH}/ucx
INSTALL_PREFIX=/opt

# Load gcc
export PATH=/opt/${GCC_VERSION}/bin:$PATH
export LD_LIBRARY_PATH=/opt/${GCC_VERSION}/lib64:$LD_LIBRARY_PATH
set CC=/opt/${GCC_VERSION}/bin/gcc
set GCC=/opt/${GCC_VERSION}/bin/gcc

# MVAPICH2 2.3.3
MV2_VERSION="2.3.3"
wget http://mvapich.cse.ohio-state.edu/download/mvapich/mv2/mvapich2-${MV2_VERSION}.tar.gz
tar -xvf mvapich2-${MV2_VERSION}.tar.gz
cd mvapich2-${MV2_VERSION}
./configure --prefix=${INSTALL_PREFIX}/mvapich2-${MV2_VERSION} --enable-g=none --enable-fast=yes && make -j$(nproc) && make install
cd ..


# OpenMPI 4.0.3
OMPI_VERSION="4.0.3"
wget https://download.open-mpi.org/release/open-mpi/v4.0/openmpi-${OMPI_VERSION}.tar.gz
tar -xvf openmpi-${OMPI_VERSION}.tar.gz
cd openmpi-${OMPI_VERSION}
./configure --prefix=${INSTALL_PREFIX}/openmpi-${OMPI_VERSION} --with-ucx=${UCX_PATH} --with-hcoll=${HCOLL_PATH} --enable-mpirun-prefix-by-default --with-platform=contrib/platform/mellanox/optimized && make -j$(nproc) && make install
cd ..


# Intel MPI 2019 (update 6)
IMPI_2019_VERSION="2019.6.166"
wget http://registrationcenter-download.intel.com/akdlm/irc_nas/tec/16120/l_mpi_${IMPI_2019_VERSION}.tgz
tar -xvf l_mpi_${IMPI_2019_VERSION}.tgz
cd l_mpi_${IMPI_2019_VERSION}
sed -i -e 's/ACCEPT_EULA=decline/ACCEPT_EULA=accept/g' silent.cfg
./install.sh --silent ./silent.cfg
cd ..


# Intel MPI 2018 (update 4)
IMPI_VERSION="2018.4.274"
wget http://registrationcenter-download.intel.com/akdlm/irc_nas/tec/13651/l_mpi_${IMPI_VERSION}.tgz
tar -xvf l_mpi_${IMPI_VERSION}.tgz
cd l_mpi_${IMPI_VERSION}
sed -i -e 's/ACCEPT_EULA=decline/ACCEPT_EULA=accept/g' silent.cfg
./install.sh --silent ./silent.cfg
cd ..


# Install MVAPICH2-X 2.3rc3
wget http://mvapich.cse.ohio-state.edu/download/mvapich/mv2x/2.3rc3/mofed5.0/mvapich2-x-advanced-xpmem-mofed5.0-gnu9.2.0-2.3rc3-1.el7.x86_64.rpm
rpm -Uvh --nodeps mvapich2-x-advanced-xpmem-mofed5.0-gnu9.2.0-2.3rc3-1.el7.x86_64.rpm
MV2X_PATH="/opt/mvapich2-x/gnu9.2.0/mofed5.0/advanced-xpmem/mpirun"
MV2X_VERSION="2.3rc3"


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

#IntelMPI-v2018
cat << EOF >> /usr/share/Modules/modulefiles/mpi/impi_${IMPI_VERSION}
#%Module 1.0
#
#  Intel MPI ${IMPI_VERSION}
#
conflict        mpi
module load /opt/intel/impi/${IMPI_VERSION}/intel64/modulefiles/mpi
EOF

#IntelMPI-v2019
cat << EOF >> /usr/share/Modules/modulefiles/mpi/impi_${IMPI_2019_VERSION}
#%Module 1.0
#
#  Intel MPI ${IMPI_2019_VERSION}
#
conflict        mpi
module load /opt/intel/impi/${IMPI_2019_VERSION}/intel64/modulefiles/mpi
EOF

# MVAPICH2-X 2.3rc3
cat << EOF >> /usr/share/Modules/modulefiles/mpi/mvapich2x-${MV2X_VERSION}
#%Module 1.0
#
#  MVAPICH2-X ${MV2X_VERSION}
#
conflict        mpi
module load ${GCC_VERSION}
prepend-path    PATH            ${MV2X_PATH}/bin
prepend-path    LD_LIBRARY_PATH ${MV2X_PATH}/lib
prepend-path    MANPATH         ${MV2X_PATH}/share/man
setenv          MPI_BIN         ${MV2X_PATH}/bin
setenv          MPI_INCLUDE     ${MV2X_PATH}/include
setenv          MPI_LIB         ${MV2X_PATH}/lib
setenv          MPI_MAN         ${MV2X_PATH}/share/man
setenv          MPI_HOME        ${MV2X_PATH}
EOF

# Create symlinks for modulefiles
ln -s /usr/share/Modules/modulefiles/mpi/mvapich2-${MV2_VERSION} /usr/share/Modules/modulefiles/mpi/mvapich2
ln -s /usr/share/Modules/modulefiles/mpi/openmpi-${OMPI_VERSION} /usr/share/Modules/modulefiles/mpi/openmpi
ln -s /usr/share/Modules/modulefiles/mpi/impi_${IMPI_2019_VERSION} /usr/share/Modules/modulefiles/mpi/impi-2019
ln -s /usr/share/Modules/modulefiles/mpi/impi_${IMPI_VERSION} /usr/share/Modules/modulefiles/mpi/impi
ln -s /usr/share/Modules/modulefiles/mpi/mvapich2x-${MV2X_VERSION} /usr/share/Modules/modulefiles/mpi/mvapich2x

