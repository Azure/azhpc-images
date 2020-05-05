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

# MVAPICH2 2.3.3
MV2_VERSION="2.3.3"
MV2_DOWNLOAD_URL=http://mvapich.cse.ohio-state.edu/download/mvapich/mv2/mvapich2-${MV2_VERSION}.tar.gz
$COMMON_DIR/download_and_verify.sh $MV2_DOWNLOAD_URL "41d3261be57e5bc8aabf4e32981543c015c5443ff032a26f18205985e18c2b73"
tar -xvf mvapich2-${MV2_VERSION}.tar.gz
cd mvapich2-${MV2_VERSION}
./configure --prefix=${INSTALL_PREFIX}/mvapich2-${MV2_VERSION} --enable-g=none --enable-fast=yes && make -j$(nproc) && make install
cd ..


# OpenMPI 4.0.3
OMPI_VERSION="4.0.3"
OMPI_DOWNLOAD_URL=https://download.open-mpi.org/release/open-mpi/v4.0/openmpi-${OMPI_VERSION}.tar.gz
$COMMON_DIR/download_and_verify.sh $OMPI_DOWNLOAD_URL "6346bf976001ad274c7e018d6cc35c92bbb9426d8f7754fac00a17ea5ac8eebc"
tar -xvf openmpi-${OMPI_VERSION}.tar.gz
cd openmpi-${OMPI_VERSION}
./configure --prefix=${INSTALL_PREFIX}/openmpi-${OMPI_VERSION} --with-ucx=${UCX_PATH} --with-hcoll=${HCOLL_PATH} --enable-mpirun-prefix-by-default --with-platform=contrib/platform/mellanox/optimized && make -j$(nproc) && make install
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

# Install MVAPICH2-X 2.3rc3
MVAPICH2X_DOWNLOAD_URL=http://mvapich.cse.ohio-state.edu/download/mvapich/mv2x/2.3rc3/mofed5.0/mvapich2-x-advanced-xpmem-mofed5.0-gnu9.2.0-2.3rc3-1.el7.x86_64.rpm
$COMMON_DIR/download_and_verify.sh $MVAPICH2X_DOWNLOAD_URL "d47617bc39056b567509b32d7ebf5d9497aad2b2fd9e1001cd9013fdf15e728c"
rpm -Uvh --nodeps mvapich2-x-advanced-xpmem-mofed5.0-gnu9.2.0-2.3rc3-1.el7.x86_64.rpm
MV2X_INSTALLATION_DIRECTORY="/opt/mvapich2-x"
MV2X_PATH="${MV2X_INSTALLATION_DIRECTORY}/gnu9.2.0/mofed5.0/advanced-xpmem/mpirun"
MV2X_VERSION="2.3rc3"

# download and build benchmark for MVAPICH2-X 2.3rc3
MVAPICH2X_BENCHMARK_DOWNLOAD_URL=http://mvapich.cse.ohio-state.edu/download/mvapich/osu-micro-benchmarks-5.6.2.tar.gz
$COMMON_DIR/download_and_verify.sh $MVAPICH2X_BENCHMARK_DOWNLOAD_URL "2ecb90abd85398786823c0716d92448d7094657d3f017c65d270ffe39afc7b95"
tar -xvf osu-micro-benchmarks-5.6.2.tar.gz
cd osu-micro-benchmarks-5.6.2/
./configure CC=${MV2X_PATH}/bin/mpicc CXX=${MV2X_PATH}/bin/mpicxx --prefix=${MV2X_INSTALLATION_DIRECTORY}/ && make -j$(nproc) && make install
cd ..

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
cat << EOF >> /usr/share/Modules/modulefiles/mpi/impi_${IMPI_2019_VERSION}
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
ln -s /usr/share/Modules/modulefiles/mpi/mvapich2x-${MV2X_VERSION} /usr/share/Modules/modulefiles/mpi/mvapich2x

