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

# Intel MPI 2018 (update 4)
IMPI_VERSION="2018.4.274"
wget http://registrationcenter-download.intel.com/akdlm/irc_nas/tec/13651/l_mpi_${IMPI_VERSION}.tgz
tar -xvf l_mpi_${IMPI_VERSION}.tgz
cd l_mpi_${IMPI_VERSION}
sed -i -e 's/ACCEPT_EULA=decline/ACCEPT_EULA=accept/g' silent.cfg
./install.sh --silent ./silent.cfg
cd ..

#IntelMPI-v2018
cat << EOF >> /usr/share/Modules/modulefiles/mpi/impi_${IMPI_VERSION}
#%Module 1.0
#
#  Intel MPI ${IMPI_VERSION}
#
conflict        mpi
module load /opt/intel/impi/${IMPI_VERSION}/intel64/modulefiles/mpi
setenv          MPI_BIN         /opt/intel/impi/${IMPI_VERSION}/intel64/bin
setenv          MPI_INCLUDE     /opt/intel/impi/${IMPI_VERSION}/intel64/include
setenv          MPI_LIB         /opt/intel/impi/${IMPI_VERSION}/intel64/lib
setenv          MPI_MAN         /opt/intel/impi/${IMPI_VERSION}/man
setenv          MPI_HOME        /opt/intel/impi/${IMPI_VERSION}/intel64
EOF

# Create symlinks for modulefiles
ln -s /usr/share/Modules/modulefiles/mpi/impi_${IMPI_VERSION} /usr/share/Modules/modulefiles/mpi/impi

../../common/install_mpis.sh ${GCC_VERSION} ${HPCX_PATH}
