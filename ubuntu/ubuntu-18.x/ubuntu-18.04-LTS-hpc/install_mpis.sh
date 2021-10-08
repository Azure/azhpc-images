#!/bin/bash
set -e

# Load gcc
GCC_VERSION=gcc-9.2.0
set CC=/usr/bin/gcc
set GCC=/usr/bin/gcc

INSTALL_PREFIX=/opt

# HPC-X v2.7.0
MLNX_OFED_VERSION="4.7-1.0.0.1"
HPCX_VERSION="v2.7.0"
$COMMON_DIR/write_component_version.sh "HPCX" ${HPCX_VERSION}
TARBALL="hpcx-${HPCX_VERSION}-gcc-MLNX_OFED_LINUX-${MLNX_OFED_VERSION}-ubuntu18.04-x86_64.tbz"
HPCX_DOWNLOAD_URL=https://azhpcstor.blob.core.windows.net/azhpc-images-store/${TARBALL}
HPCX_FOLDER=$(basename ${HPCX_DOWNLOAD_URL} .tbz)

$COMMON_DIR/download_and_verify.sh $HPCX_DOWNLOAD_URL "83f03e2d01cb1e4198e50ed9bdadb742aebf5d247369071bc911096824147d7a"
tar -xvf ${TARBALL}
mv ${HPCX_FOLDER} ${INSTALL_PREFIX}
HPCX_PATH=${INSTALL_PREFIX}/${HPCX_FOLDER}

# MVAPICH2 2.3.6
MV2_VERSION="2.3.6"
$COMMON_DIR/write_component_version.sh "MVAPICH2" ${MV2_VERSION}
MV2_DOWNLOAD_URL=http://mvapich.cse.ohio-state.edu/download/mvapich/mv2/mvapich2-${MV2_VERSION}.tar.gz
$COMMON_DIR/download_and_verify.sh $MV2_DOWNLOAD_URL "b3a62f2a05407191b856485f99da05f5e769d6381cd63e2fcb83ee98fc46a249"
tar -xvf mvapich2-${MV2_VERSION}.tar.gz
cd mvapich2-${MV2_VERSION}
./configure --prefix=${INSTALL_PREFIX}/mvapich2-${MV2_VERSION} --enable-g=none --enable-fast=yes && make -j$(nproc) && make install
cd ..

# OpenMPI 4.1.1
OMPI_VERSION="4.1.1"
$COMMON_DIR/write_component_version.sh "OMPI" ${OMPI_VERSION}
OMPI_DOWNLOAD_URL=https://download.open-mpi.org/release/open-mpi/v4.1/openmpi-${OMPI_VERSION}.tar.gz
$COMMON_DIR/download_and_verify.sh $OMPI_DOWNLOAD_URL "d80b9219e80ea1f8bcfe5ad921bd9014285c4948c5965f4156a3831e60776444"
tar -xvf openmpi-${OMPI_VERSION}.tar.gz
cd openmpi-${OMPI_VERSION}
# disable OpenSHMEM build
sed -i "s/enable_oshmem_fortran=yes/enable_oshmem_fortran=no/" contrib/platform/mellanox/optimized
sed -i "s/enable_oshmem=yes/enable_oshmem=no/" contrib/platform/mellanox/optimized
./configure --prefix=${INSTALL_PREFIX}/openmpi-${OMPI_VERSION} --with-ucx=${UCX_PATH} --with-hcoll=${HCOLL_PATH} --enable-mpirun-prefix-by-default --disable-oshmem --with-platform=contrib/platform/mellanox/optimized && make -j$(nproc) && make install
cd ..

# Intel MPI 2021 (Update 2)
IMPI_2021_VERSION="2021.4.0"
$COMMON_DIR/write_component_version.sh "IMPI_2021" ${IMPI_2021_VERSION}
IMPI_2021_DOWNLOAD_URL=https://registrationcenter-download.intel.com/akdlm/irc_nas/18186/l_mpi_oneapi_p_2021.4.0.441_offline.sh
$COMMON_DIR/download_and_verify.sh $IMPI_2021_DOWNLOAD_URL "cc4b7072c61d0bd02b1c431b22d2ea3b84b967b59d2e587e77a9e7b2c24f2a29"
bash l_mpi_oneapi_p_2021.4.0.441_offline.sh -s -a -s --eula accept
mv ${INSTALL_PREFIX}/intel/oneapi/mpi/${IMPI_2021_VERSION}/modulefiles/mpi ${INSTALL_PREFIX}/intel/oneapi/mpi/${IMPI_2021_VERSION}/modulefiles/impi

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
