#!/bin/bash
set -ex

# Load gcc
GCC_VERSION=gcc-9.2.0
set CC=/usr/bin/gcc
set GCC=/usr/bin/gcc

INSTALL_PREFIX=/opt

# HPC-X v2.7.0
MLNX_OFED_VERSION="4.7-1.0.0.1"
HPCX_VERSION="v2.7.0"
TARBALL="hpcx-${HPCX_VERSION}-gcc-MLNX_OFED_LINUX-${MLNX_OFED_VERSION}-${DISTRIBUTION}-x86_64.tbz"
HPCX_DOWNLOAD_URL=https://azhpcstor.blob.core.windows.net/azhpc-images-store/${TARBALL}
HPCX_FOLDER=$(basename ${HPCX_DOWNLOAD_URL} .tbz)

$COMMON_DIR/download_and_verify.sh $HPCX_DOWNLOAD_URL "83f03e2d01cb1e4198e50ed9bdadb742aebf5d247369071bc911096824147d7a"
tar -xvf ${TARBALL}
mv ${HPCX_FOLDER} ${INSTALL_PREFIX}
HPCX_PATH=${INSTALL_PREFIX}/${HPCX_FOLDER}
$COMMON_DIR/write_component_version.sh "HPCX" ${HPCX_VERSION}

# MVAPICH2 2.3.7
MV2_VERSION="2.3.7"
MV2_DOWNLOAD_URL=http://mvapich.cse.ohio-state.edu/download/mvapich/mv2/mvapich2-${MV2_VERSION}.tar.gz
$COMMON_DIR/download_and_verify.sh $MV2_DOWNLOAD_URL "c39a4492f4be50df6100785748ba2894e23ce450a94128181d516da5757751ae"
tar -xvf mvapich2-${MV2_VERSION}.tar.gz
cd mvapich2-${MV2_VERSION}
./configure --prefix=${INSTALL_PREFIX}/mvapich2-${MV2_VERSION} --enable-g=none --enable-fast=yes && make -j$(nproc) && make install
cd ..
$COMMON_DIR/write_component_version.sh "MVAPICH2" ${MV2_VERSION}

# OpenMPI 4.1.3
OMPI_VERSION="4.1.3"
OMPI_DOWNLOAD_URL=https://download.open-mpi.org/release/open-mpi/v4.1/openmpi-${OMPI_VERSION}.tar.gz
$COMMON_DIR/download_and_verify.sh $OMPI_DOWNLOAD_URL "9c0fd1f78fc90ca9b69ae4ab704687d5544220005ccd7678bf58cc13135e67e0"
tar -xvf openmpi-${OMPI_VERSION}.tar.gz
cd openmpi-${OMPI_VERSION}
# disable OpenSHMEM build
sed -i "s/enable_oshmem_fortran=yes/enable_oshmem_fortran=no/" contrib/platform/mellanox/optimized
sed -i "s/enable_oshmem=yes/enable_oshmem=no/" contrib/platform/mellanox/optimized
./configure --prefix=${INSTALL_PREFIX}/openmpi-${OMPI_VERSION} --with-ucx=${UCX_PATH} --with-hcoll=${HCOLL_PATH} --enable-mpirun-prefix-by-default --disable-oshmem --with-platform=contrib/platform/mellanox/optimized && make -j$(nproc) && make install
cd ..
$COMMON_DIR/write_component_version.sh "OMPI" ${OMPI_VERSION}

# Intel MPI 2021 (Update 7)
IMPI_2021_VERSION="2021.7.0"
IMPI_2021_DOWNLOAD_URL=https://registrationcenter-download.intel.com/akdlm/irc_nas/18926/l_mpi_oneapi_p_${IMPI_2021_VERSION}.8711_offline.sh
$COMMON_DIR/download_and_verify.sh $IMPI_2021_DOWNLOAD_URL "4eb1e1487b67b98857bc9b7b37bcac4998e0aa6d1b892b2c87b003bf84fb38e9"
bash l_mpi_oneapi_p_${IMPI_2021_VERSION}.8711_offline.sh -s -a -s --eula accept
mv ${INSTALL_PREFIX}/intel/oneapi/mpi/${IMPI_2021_VERSION}/modulefiles/mpi ${INSTALL_PREFIX}/intel/oneapi/mpi/${IMPI_2021_VERSION}/modulefiles/impi
$COMMON_DIR/write_component_version.sh "IMPI_2021" ${IMPI_2021_VERSION}

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
cat << EOF >> ${MODULE_FILES_DIRECTORY}/openmpi-${OMPI_VERSION}
#%Module 1.0
#
#  OpenMPI ${OMPI_VERSION}
#
conflict        mpi
prepend-path    PATH            /opt/openmpi-${OMPI_VERSION}/bin
prepend-path    LD_LIBRARY_PATH /opt/openmpi-${OMPI_VERSION}/lib
prepend-path    MANPATH         /opt/openmpi-${OMPI_VERSION}/share/man
setenv          MPI_BIN         /opt/openmpi-${OMPI_VERSION}/bin
setenv          MPI_INCLUDE     /opt/openmpi-${OMPI_VERSION}/include
setenv          MPI_LIB         /opt/openmpi-${OMPI_VERSION}/lib
setenv          MPI_MAN         /opt/openmpi-${OMPI_VERSION}/share/man
setenv          MPI_HOME        /opt/openmpi-${OMPI_VERSION}
EOF

# Intel 2021
cat << EOF >> ${MODULE_FILES_DIRECTORY}/impi_${IMPI_2021_VERSION}
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

# Softlinks
ln -s ${MODULE_FILES_DIRECTORY}/hpcx-${HPCX_VERSION} ${MODULE_FILES_DIRECTORY}/hpcx
ln -s ${MODULE_FILES_DIRECTORY}/mvapich2-${MV2_VERSION} ${MODULE_FILES_DIRECTORY}/mvapich2
ln -s ${MODULE_FILES_DIRECTORY}/openmpi-${OMPI_VERSION} ${MODULE_FILES_DIRECTORY}/openmpi
ln -s ${MODULE_FILES_DIRECTORY}/impi_${IMPI_2021_VERSION} ${MODULE_FILES_DIRECTORY}/impi-2021
