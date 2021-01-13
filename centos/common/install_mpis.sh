#!/bin/bash
set -e

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

# MVAPICH2 2.3.5
MV2_VERSION="2.3.5"
MV2_DOWNLOAD_URL=http://mvapich.cse.ohio-state.edu/download/mvapich/mv2/mvapich2-${MV2_VERSION}.tar.gz
$COMMON_DIR/download_and_verify.sh $MV2_DOWNLOAD_URL "f9f467fec5fc981a89a7beee0374347b10c683023c76880f92a1a0ad4b961a8c"
tar -xvf mvapich2-${MV2_VERSION}.tar.gz
cd mvapich2-${MV2_VERSION}
./configure --prefix=${INSTALL_PREFIX}/mvapich2-${MV2_VERSION} --enable-g=none --enable-fast=yes && make -j$(nproc) && make install
cd ..


# OpenMPI 4.1.0
OMPI_VERSION="4.1.0"
OMPI_DOWNLOAD_URL=https://download.open-mpi.org/release/open-mpi/v4.1/openmpi-${OMPI_VERSION}.tar.gz
$COMMON_DIR/download_and_verify.sh $OMPI_DOWNLOAD_URL "228467c3dd15339d9b26cf26a291af3ee7c770699c5e8a1b3ad786f9ae78140a"
tar -xvf openmpi-${OMPI_VERSION}.tar.gz
cd openmpi-${OMPI_VERSION}
./configure --prefix=${INSTALL_PREFIX}/openmpi-${OMPI_VERSION} --with-ucx=${UCX_PATH} --with-hcoll=${HCOLL_PATH} --enable-mpirun-prefix-by-default --with-platform=contrib/platform/mellanox/optimized && make -j$(nproc) && make install
cd ..

# Intel MPI 2019 (update 8)
# IMPI_2019_VERSION="2019.8.254"
# IMPI_2019_DOWNLOAD_URL=http://registrationcenter-download.intel.com/akdlm/irc_nas/tec/16814/l_mpi_${IMPI_2019_VERSION}.tgz
# $COMMON_DIR/download_and_verify.sh $IMPI_2019_DOWNLOAD_URL "fa163b4b79bd1b7509980c3e7ad81b354fc281a92f9cf2469bf4d323899567c0"
# tar -xvf l_mpi_${IMPI_2019_VERSION}.tgz
# cd l_mpi_${IMPI_2019_VERSION}
# sed -i -e 's/ACCEPT_EULA=decline/ACCEPT_EULA=accept/g' silent.cfg
# ./install.sh --silent ./silent.cfg
# cd ..

# Intel MPI 2021 (update 1) - oneAPI
IMPI_2021_VERSION="2021.1.1"
IMPI_2021_DOWNLOAD_URL=https://registrationcenter-download.intel.com/akdlm/irc_nas/17397/l_mpi_oneapi_p_2021.1.1.76_offline.sh
$COMMON_DIR/download_and_verify.sh $IMPI_2021_DOWNLOAD_URL "8b7693a156c6fc6269637bef586a8fd3ea6610cac2aae4e7f48c1fbb601625fe"
./l_mpi_oneapi_p_2021.1.1.76_offline.sh -s -a -s --eula accept

# Install MVAPICH2-X 2.3
#MVAPICH2X_DOWNLOAD_URL=https://mvapich.cse.ohio-state.edu/download/mvapich/mv2x/2.3/mofed5.1/mvapich2-x-azure-xpmem-mofed5.1-gnu9.2.0-v2.3xmofed5-1.el7.x86_64.rpm
#$COMMON_DIR/download_and_verify.sh $MVAPICH2X_DOWNLOAD_URL "cbccc85ebbcdea4769999a42a45d40c9a22bf000410f46de219d69a0ef0291b6"
#rpm -Uvh --nodeps mvapich2-x-azure-xpmem-mofed5.1-gnu9.2.0-v2.3xmofed5-1.el7.x86_64.rpm
#MV2X_INSTALLATION_DIRECTORY="/opt/mvapich2-x"
#MV2X_PATH="${MV2X_INSTALLATION_DIRECTORY}/gnu9.2.0/mofed5.1/azure-xpmem/mpirun"
#MV2X_VERSION="2.3"

# download and build benchmark for MVAPICH2-X 2.3
#MVAPICH2X_BENCHMARK_DOWNLOAD_URL=http://mvapich.cse.ohio-state.edu/download/mvapich/osu-micro-benchmarks-5.6.3.tar.gz
#$COMMON_DIR/download_and_verify.sh $MVAPICH2X_BENCHMARK_DOWNLOAD_URL "c5eaa8c5b086bde8514fa4cac345d66b397e02283bc06e44cb6402268a60aeb8"
#tar -xvf osu-micro-benchmarks-5.6.3.tar.gz
#cd osu-micro-benchmarks-5.6.3/
#./configure CC=${MV2X_PATH}/bin/mpicc CXX=${MV2X_PATH}/bin/mpicxx --prefix=${MV2X_INSTALLATION_DIRECTORY}/ && make -j$(nproc) && make install
#cd ..

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

#IntelMPI-v2019
# cat << EOF >> /usr/share/Modules/modulefiles/mpi/impi_${IMPI_2019_VERSION}
# #%Module 1.0
# #
# #  Intel MPI ${IMPI_2019_VERSION}
# #
# conflict        mpi
# module load /opt/intel/impi/${IMPI_2019_VERSION}/intel64/modulefiles/mpi
# setenv          MPI_BIN         /opt/intel/impi/${IMPI_2019_VERSION}/intel64/bin
# setenv          MPI_INCLUDE     /opt/intel/impi/${IMPI_2019_VERSION}/intel64/include
# setenv          MPI_LIB         /opt/intel/impi/${IMPI_2019_VERSION}/intel64/lib
# setenv          MPI_MAN         /opt/intel/impi/${IMPI_2019_VERSION}/man
# setenv          MPI_HOME        /opt/intel/impi/${IMPI_2019_VERSION}/intel64
# EOF

#IntelMPI-v2021
cat << EOF >> /usr/share/Modules/modulefiles/mpi/impi_${IMPI_2021_VERSION}
#%Module 1.0
#
#  Intel MPI ${IMPI_2021_VERSION}
#
conflict        mpi
module load /opt/intel/oneapi/mpi/${IMPI_2021_VERSION}/modulefiles/mpi
setenv          MPI_BIN         /opt/intel/oneapi/mpi/${IMPI_2021_VERSION}/bin
setenv          MPI_INCLUDE     /opt/intel/oneapi/mpi/${IMPI_2021_VERSION}/include
setenv          MPI_LIB         /opt/intel/oneapi/mpi/${IMPI_2021_VERSION}/lib
setenv          MPI_MAN         /opt/intel/oneapi/mpi/${IMPI_2021_VERSION}/man
setenv          MPI_HOME        /opt/intel/oneapi/mpi/${IMPI_2021_VERSION}
EOF

# MVAPICH2-X 2.3
#cat << EOF >> /usr/share/Modules/modulefiles/mpi/mvapich2x-${MV2X_VERSION}
##%Module 1.0
##
##  MVAPICH2-X ${MV2X_VERSION}
##
#conflict        mpi
#module load ${GCC_VERSION}
#prepend-path    PATH            ${MV2X_PATH}/bin
#prepend-path    LD_LIBRARY_PATH ${MV2X_PATH}/lib
#prepend-path    MANPATH         ${MV2X_PATH}/share/man
#setenv          MPI_BIN         ${MV2X_PATH}/bin
#setenv          MPI_INCLUDE     ${MV2X_PATH}/include
#setenv          MPI_LIB         ${MV2X_PATH}/lib
#setenv          MPI_MAN         ${MV2X_PATH}/share/man
#setenv          MPI_HOME        ${MV2X_PATH}
#EOF

# Create symlinks for modulefiles
ln -s /usr/share/Modules/modulefiles/mpi/mvapich2-${MV2_VERSION} /usr/share/Modules/modulefiles/mpi/mvapich2
ln -s /usr/share/Modules/modulefiles/mpi/openmpi-${OMPI_VERSION} /usr/share/Modules/modulefiles/mpi/openmpi
# ln -s /usr/share/Modules/modulefiles/mpi/impi_${IMPI_2019_VERSION} /usr/share/Modules/modulefiles/mpi/impi-2019
ln -s /usr/share/Modules/modulefiles/mpi/impi_${IMPI_2021_VERSION} /usr/share/Modules/modulefiles/mpi/impi-2021
#ln -s /usr/share/Modules/modulefiles/mpi/mvapich2x-${MV2X_VERSION} /usr/share/Modules/modulefiles/mpi/mvapich2x

