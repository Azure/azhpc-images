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

# Install Intel MPI
impi_metadata=$(jq -r '.impi."'"$DISTRIBUTION"'"' <<< $COMPONENT_VERSIONS)
IMPI_VERSION=$(jq -r '.version' <<< $impi_metadata)
IMPI_SHA256=$(jq -r '.sha256' <<< $impi_metadata)
IMPI_DOWNLOAD_URL=$(jq -r '.url' <<< $impi_metadata)
TARBALL=$(basename $IMPI_DOWNLOAD_URL)
IMPI_FOLDER=$(basename $IMPI_DOWNLOAD_URL .tbz)

$COMMON_DIR/write_component_version.sh "IMPI" ${IMPI_VERSION}
$COMMON_DIR/download_and_verify.sh $IMPI_DOWNLOAD_URL $IMPI_SHA256
tar -xvf ${TARBALL}
cd ${IMPI_FOLDER}
# Update the silent.cfg file to proceed with installation
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
