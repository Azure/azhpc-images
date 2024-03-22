#!/bin/bash
set -ex

# Load gcc
set CC=/usr/bin/gcc
set GCC=/usr/bin/gcc

INSTALL_PREFIX=/opt

# HPC-X v2.16
hpcx_metadata=$(jq -r '.hpcx."'"$DISTRIBUTION"'"' <<< $COMPONENT_VERSIONS)
HPCX_VERSION=$(jq -r '.version' <<< $hpcx_metadata)
HPCX_SHA256=$(jq -r '.sha256' <<< $hpcx_metadata)
HPCX_DOWNLOAD_URL=$(jq -r '.url' <<< $hpcx_metadata)
TARBALL=$(basename $HPCX_DOWNLOAD_URL)
HPCX_FOLDER=$(basename $HPCX_DOWNLOAD_URL .tbz)

$COMMON_DIR/download_and_verify.sh ${HPCX_DOWNLOAD_URL} ${HPCX_SHA256}
tar -xvf ${TARBALL}
mv ${HPCX_FOLDER} ${INSTALL_PREFIX}
HPCX_PATH=${INSTALL_PREFIX}/${HPCX_FOLDER}
$COMMON_DIR/write_component_version.sh "HPCX" $HPCX_VERSION

# Install MVAPICH2
mvapich2_metadata=$(jq -r '.mvapich2."'"$DISTRIBUTION"'"' <<< $COMPONENT_VERSIONS)
MVAPICH2_VERSION=$(jq -r '.version' <<< $mvapich2_metadata)
MVAPICH2_SHA256=$(jq -r '.sha256' <<< $mvapich2_metadata)
MVAPICH2_DOWNLOAD_URL=http://mvapich.cse.ohio-state.edu/download/mvapich/mv2/mvapich2-${MVAPICH2_VERSION}.tar.gz
TARBALL=$(basename $MVAPICH2_DOWNLOAD_URL)
MVAPICH2_FOLDER=$(basename $MVAPICH2_DOWNLOAD_URL .tar.gz)

$COMMON_DIR/download_and_verify.sh $MVAPICH2_DOWNLOAD_URL $MVAPICH2_SHA256
tar -xvf ${TARBALL}
cd ${MVAPICH2_FOLDER}
# Error exclusive to Ubuntu 22.04
# configure: error: The Fortran compiler gfortran will not compile files that call
# the same routine with arguments of different types.
./configure $(if [[ ${DISTRIBUTION} == "ubuntu22.04" ]]; then echo "FFLAGS=-fallow-argument-mismatch"; fi) --prefix=${INSTALL_PREFIX}/mvapich2-${MVAPICH2_VERSION} --enable-g=none --enable-fast=yes && make -j$(nproc) && make install
cd ..
$COMMON_DIR/write_component_version.sh "MVAPICH2" ${MVAPICH2_VERSION}

# Install Open MPI
ompi_metadata=$(jq -r '.ompi."'"$DISTRIBUTION"'"' <<< $COMPONENT_VERSIONS)
OMPI_VERSION=$(jq -r '.version' <<< $ompi_metadata)
OMPI_SHA256=$(jq -r '.sha256' <<< $ompi_metadata)
OMPI_DOWNLOAD_URL=$(jq -r '.url' <<< $ompi_metadata)
TARBALL=$(basename $OMPI_DOWNLOAD_URL)
OMPI_FOLDER=$(basename $OMPI_DOWNLOAD_URL .tar.gz)

$COMMON_DIR/download_and_verify.sh $OMPI_DOWNLOAD_URL $OMPI_SHA256
tar -xvf $TARBALL
cd $OMPI_FOLDER
./configure --prefix=${INSTALL_PREFIX}/openmpi-${OMPI_VERSION} --with-ucx=${UCX_PATH} --with-hcoll=${HCOLL_PATH} --enable-mpirun-prefix-by-default --with-platform=contrib/platform/mellanox/optimized && make -j$(nproc) && make install
cd ..
$COMMON_DIR/write_component_version.sh "OMPI" ${OMPI_VERSION}

# Install Intel MPI
impi_metadata=$(jq -r '.impi."'"$DISTRIBUTION"'"' <<< $COMPONENT_VERSIONS)
IMPI_VERSION=$(jq -r '.version' <<< $impi_metadata)
IMPI_SHA256=$(jq -r '.sha256' <<< $impi_metadata)
IMPI_DOWNLOAD_URL=$(jq -r '.url' <<< $impi_metadata)
IMPI_OFFLINE_INSTALLER=$(basename $IMPI_DOWNLOAD_URL)

$COMMON_DIR/download_and_verify.sh $IMPI_DOWNLOAD_URL $IMPI_SHA256
bash $IMPI_OFFLINE_INSTALLER -s -a -s --eula accept

impi_2021_version=${IMPI_VERSION:0:-2}
mv ${INSTALL_PREFIX}/intel/oneapi/mpi/${impi_2021_version}/etc/modulefiles/mpi ${INSTALL_PREFIX}/intel/oneapi/mpi/${impi_2021_version}/etc/modulefiles/impi
$COMMON_DIR/write_component_version.sh "IMPI" ${IMPI_VERSION}

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
cat << EOF >> ${MODULE_FILES_DIRECTORY}/mvapich2-${MVAPICH2_VERSION}
#%Module 1.0
#
#  MVAPICH2 ${MVAPICH2_VERSION}
#
conflict        mpi
prepend-path    PATH            /opt/mvapich2-${MVAPICH2_VERSION}/bin
prepend-path    LD_LIBRARY_PATH /opt/mvapich2-${MVAPICH2_VERSION}/lib
prepend-path    MANPATH         /opt/mvapich2-${MVAPICH2_VERSION}/share/man
setenv          MPI_BIN         /opt/mvapich2-${MVAPICH2_VERSION}/bin
setenv          MPI_INCLUDE     /opt/mvapich2-${MVAPICH2_VERSION}/include
setenv          MPI_LIB         /opt/mvapich2-${MVAPICH2_VERSION}/lib
setenv          MPI_MAN         /opt/mvapich2-${MVAPICH2_VERSION}/share/man
setenv          MPI_HOME        /opt/mvapich2-${MVAPICH2_VERSION}
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
cat << EOF >> ${MODULE_FILES_DIRECTORY}/impi_${IMPI_VERSION}
#%Module 1.0
#
#  Intel MPI ${IMPI_VERSION}
#
conflict        mpi
module load /opt/intel/oneapi/mpi/${IMPI_VERSION}/modulefiles/impi
setenv          MPI_BIN         /opt/intel/oneapi/mpi/${IMPI_VERSION}/bin
setenv          MPI_INCLUDE     /opt/intel/oneapi/mpi/${IMPI_VERSION}/include
setenv          MPI_LIB         /opt/intel/oneapi/mpi/${IMPI_VERSION}/lib
setenv          MPI_MAN         /opt/intel/oneapi/mpi/${IMPI_VERSION}/man
setenv          MPI_HOME        /opt/intel/oneapi/mpi/${IMPI_VERSION}
EOF

# Softlinks
ln -s ${MODULE_FILES_DIRECTORY}/hpcx-${HPCX_VERSION} ${MODULE_FILES_DIRECTORY}/hpcx
ln -s ${MODULE_FILES_DIRECTORY}/mvapich2-${MVAPICH2_VERSION} ${MODULE_FILES_DIRECTORY}/mvapich2
ln -s ${MODULE_FILES_DIRECTORY}/openmpi-${OMPI_VERSION} ${MODULE_FILES_DIRECTORY}/openmpi
ln -s ${MODULE_FILES_DIRECTORY}/impi_${impi_2021_version} ${MODULE_FILES_DIRECTORY}/impi-2021
