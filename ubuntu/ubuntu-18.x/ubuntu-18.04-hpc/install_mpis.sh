#!/bin/bash
set -e

# Load gcc
GCC_VERSION=gcc-9.2.0
export PATH=/opt/${GCC_VERSION}/bin:$PATH
export LD_LIBRARY_PATH=/opt/${GCC_VERSION}/lib64:$LD_LIBRARY_PATH
set CC=/opt/${GCC_VERSION}/bin/gcc
set GCC=/opt/${GCC_VERSION}/bin/gcc

INSTALL_PREFIX=/opt

# HPC-X v2.6.0
HPCX_VERSION="v2.6.0"

HPCX_DOWNLOAD_URL=http://www.mellanox.com/downloads/hpc/hpc-x/v2.6/hpcx-v2.6.0-gcc-MLNX_OFED_LINUX-5.0-1.0.0.0-ubuntu18.04-x86_64.tbz
$COMMON_DIR/download_and_verify.sh $HPCX_DOWNLOAD_URL "15f27a3f14d6e90c5b08f5ffd43e836b570ebf78b9b240042c35c071d90c43c2"
tar -xvf hpcx-${HPCX_VERSION}-gcc-MLNX_OFED_LINUX-5.0-1.0.0.0-ubuntu18.04-x86_64.tbz
mv hpcx-${HPCX_VERSION}-gcc-MLNX_OFED_LINUX-5.0-1.0.0.0-ubuntu18.04-x86_64  ${INSTALL_PREFIX}

HPCX_PATH=${INSTALL_PREFIX}/hpcx-${HPCX_VERSION}-gcc-MLNX_OFED_LINUX-5.0-1.0.0.0-ubuntu18.04-x86_64

# MVAPICH2 2.3.3
MV2_VERSION="2.3.3"

MV2_DOWNLOAD_URL=http://mvapich.cse.ohio-state.edu/download/mvapich/mv2/mvapich2-${MV2_VERSION}.tar.gz
$COMMON_DIR/download_and_verify.sh $MV2_DOWNLOAD_URL "41d3261be57e5bc8aabf4e32981543c015c5443ff032a26f18205985e18c2b73"
tar -xvf mvapich2-${MV2_VERSION}.tar.gz
cd mvapich2-${MV2_VERSION}
./configure --prefix=${INSTALL_PREFIX}/mvapich2-${MV2_VERSION} --enable-g=none --enable-fast=yes && make -j$(nproc) && make install
cd ..

# Intel MPI 2019 (update 7)
IMPI_2019_VERSION="2019.7.217"

IMPI_2019_DOWNLOAD_URL=http://registrationcenter-download.intel.com/akdlm/irc_nas/tec/16546/l_mpi_${IMPI_2019_VERSION}.tgz
$COMMON_DIR/download_and_verify.sh $IMPI_2019_DOWNLOAD_URL "90383b0023f84ac003a55d8bb29dbcf0c639f43a25a2d8d8698a16e770ac9c07"
tar -xvf l_mpi_${IMPI_2019_VERSION}.tgz
cd l_mpi_${IMPI_2019_VERSION}
sed -i -e 's/ACCEPT_EULA=decline/ACCEPT_EULA=accept/g' silent.cfg
./install.sh --silent ./silent.cfg
cd ..

# Module Files
MODULE_FILES_DIRECTORY=/usr/share/modules/modulefiles/mpi
mkdir -p ${MODULE_FILES_DIRECTORY}

# HPC-X
cat << EOF >> ${MODULE_FILES_DIRECTORY}/hpcx-${HPCX_VERSION}
#%Module 1.0
#
#  HPCx ${HPCX_VERSION}
#
conflict        mpi
module load ${HPCX_PATH}/modulefiles/hpcx
EOF

# MVAPICH2
cat << EOF >> ${MODULE_FILES_DIRECTORY}/mvapich2-${MV2_VERSION}
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

# Intel 2019
cat << EOF >> ${MODULE_FILES_DIRECTORY}/impi_${IMPI_2019_VERSION}
#%Module 1.0
#
#  Intel MPI ${IMPI_2019_VERSION}
#
conflict        mpi
module load /opt/intel/impi/${IMPI_2019_VERSION}/intel64/modulefiles/mpi
setenv          MPI_BIN         /opt/intel/impi/${IMPI_2019_VERSION}/intel64/bin
setenv          MPI_INCLUDE     /opt/intel/impi/${IMPI_2019_VERSION}/intel64/include
setenv          MPI_LIB         /opt/intel/impi/${IMPI_2019_VERSION}/intel64/lib
setenv          MPI_MAN         /opt/intel/impi/${IMPI_2019_VERSION}/man
setenv          MPI_HOME        /opt/intel/impi/${IMPI_2019_VERSION}/intel64
EOF

# Softlinks
ln -s ${MODULE_FILES_DIRECTORY}/hpcx-${HPCX_VERSION} ${MODULE_FILES_DIRECTORY}/hpcx
ln -s ${MODULE_FILES_DIRECTORY}/mvapich2-${MV2_VERSION} ${MODULE_FILES_DIRECTORY}/mvapich2
ln -s ${MODULE_FILES_DIRECTORY}/impi_${IMPI_2019_VERSION} ${MODULE_FILES_DIRECTORY}/impi-2019
