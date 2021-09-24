#!/bin/bash
set -ex

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
$COMMON_DIR/write_component_version.sh "IMPI_2018" ${IMPI_VERSION}
IMPI_2018_DOWNLOAD_URL=http://registrationcenter-download.intel.com/akdlm/irc_nas/tec/13651/l_mpi_${IMPI_VERSION}.tgz
$COMMON_DIR/download_and_verify.sh $IMPI_2018_DOWNLOAD_URL "a1114b3eb4149c2f108964b83cad02150d619e50032059d119ac4ffc9d5dd8e0"
tar -xvf l_mpi_${IMPI_VERSION}.tgz
cd l_mpi_${IMPI_VERSION}
sed -i -e 's/ACCEPT_EULA=decline/ACCEPT_EULA=accept/g' silent.cfg
./install.sh --silent ./silent.cfg
cd ..

# Create symlinks for modulefiles
ln -s /opt/intel/impi/${IMPI_VERSION}/intel64/modulefiles/mpi /usr/share/Modules/modulefiles/mpi/impi
ln -s /opt/intel/impi/${IMPI_VERSION}/intel64/modulefiles/mpi /usr/share/Modules/modulefiles/mpi/impi_${IMPI_VERSION}

../../common/install_mpis.sh ${GCC_VERSION} ${HPCX_PATH}
