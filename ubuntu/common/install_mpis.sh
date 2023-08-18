#!/bin/bash
set -ex

# Parameters
HPCX_CHECKSUM=$1

# Load gcc
set CC=/usr/bin/gcc
set GCC=/usr/bin/gcc

INSTALL_PREFIX=/opt

# HPC-X v2.15
HPCX_VERSION="v2.16"
TARBALL="hpcx-${HPCX_VERSION}-gcc-mlnx_ofed-$DISTRIBUTION-cuda12-gdrcopy2-nccl2.18-x86_64.tbz"
HPCX_DOWNLOAD_URL=https://content.mellanox.com/hpc/hpc-x/${HPCX_VERSION}/${TARBALL}
HPCX_FOLDER=$(basename ${HPCX_DOWNLOAD_URL} .tbz)

$COMMON_DIR/download_and_verify.sh ${HPCX_DOWNLOAD_URL} ${HPCX_CHECKSUM}
tar -xvf ${TARBALL}
mv ${HPCX_FOLDER} ${INSTALL_PREFIX}
HPCX_PATH=${INSTALL_PREFIX}/${HPCX_FOLDER}
$COMMON_DIR/write_component_version.sh "HPCX" $HPCX_VERSION

# MVAPICH2 2.3.7-1
MV2_VERSION="2.3.7-1"
MV2_DOWNLOAD_URL=http://mvapich.cse.ohio-state.edu/download/mvapich/mv2/mvapich2-${MV2_VERSION}.tar.gz
$COMMON_DIR/download_and_verify.sh $MV2_DOWNLOAD_URL "fdd971cf36d6476d007b5d63d19414546ca8a2937b66886f24a1d9ca154634e4"
tar -xvf mvapich2-${MV2_VERSION}.tar.gz
cd mvapich2-${MV2_VERSION}
# Error exclusive to Ubuntu 22.04
# configure: error: The Fortran compiler gfortran will not compile files that call
# the same routine with arguments of different types.
./configure $(if [[ ${DISTRIBUTION} == "ubuntu22.04" ]]; then echo "FFLAGS=-fallow-argument-mismatch"; fi) --prefix=${INSTALL_PREFIX}/mvapich2-${MV2_VERSION} --enable-g=none --enable-fast=yes && make -j$(nproc) && make install
cd ..
$COMMON_DIR/write_component_version.sh "MVAPICH2" ${MV2_VERSION}

# OpenMPI 4.1.5
OMPI_VERSION="4.1.5"
OMPI_DOWNLOAD_URL=https://download.open-mpi.org/release/open-mpi/v4.1/openmpi-${OMPI_VERSION}.tar.gz
$COMMON_DIR/download_and_verify.sh $OMPI_DOWNLOAD_URL "c018b127619d2a2a30c1931f316fc8a245926d0f5b4ebed4711f9695e7f70925"
tar -xvf openmpi-${OMPI_VERSION}.tar.gz
cd openmpi-${OMPI_VERSION}
./configure --prefix=${INSTALL_PREFIX}/openmpi-${OMPI_VERSION} --with-ucx=${UCX_PATH} --with-hcoll=${HCOLL_PATH} --enable-mpirun-prefix-by-default --with-platform=contrib/platform/mellanox/optimized && make -j$(nproc) && make install
cd ..
$COMMON_DIR/write_component_version.sh "OMPI" ${OMPI_VERSION}

# Intel MPI 2021 (Update 10)
IMPI_2021_VERSION="2021.10.0.49374"
IMPI_2021_DOWNLOAD_URL=https://registrationcenter-download.intel.com/akdlm/IRC_NAS/718d6f8f-2546-4b36-b97b-bc58d5482ebf/l_mpi_oneapi_p_${IMPI_2021_VERSION}_offline.sh
$COMMON_DIR/download_and_verify.sh $IMPI_2021_DOWNLOAD_URL "ab2e97d87b139201a2e7dab9a61ac6e8927b7783b459358c4ad69a1b1c064f40"
bash l_mpi_oneapi_p_${IMPI_2021_VERSION}_offline.sh -s -a -s --eula accept
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
