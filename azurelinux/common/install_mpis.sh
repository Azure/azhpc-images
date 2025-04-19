#!/bin/bash
set -ex

source ${COMMON_DIR}/utilities.sh

# Load gcc
set CC=/usr/bin/gcc
set GCC=/usr/bin/gcc

INSTALL_PREFIX=/opt

# Install HPC-x
hpcx_metadata=$(get_component_config "hpcx")
HPCX_VERSION=$(jq -r '.version' <<< $hpcx_metadata)
HPCX_SHA256=$(jq -r '.sha256' <<< $hpcx_metadata)
HPCX_DOWNLOAD_URL=$(jq -r '.url' <<< $hpcx_metadata)
TARBALL=$(basename $HPCX_DOWNLOAD_URL)
HPCX_FOLDER=$(basename $HPCX_DOWNLOAD_URL .tbz)

pmix_metadata=$(get_component_config "pmix")
PMIX_VERSION=$(jq -r '.version' <<< $pmix_metadata)
# PMIX_PATH=${INSTALL_PREFIX}/pmix/${PMIX_VERSION:0:-2}

$COMMON_DIR/download_and_verify.sh $HPCX_DOWNLOAD_URL $HPCX_SHA256
tar -xvf ${TARBALL}

# Enables ompi configuration
sed -i "s/\/build-result\//\/opt\//" ${HPCX_FOLDER}/hcoll/lib/pkgconfig/hcoll.pc

mv ${HPCX_FOLDER} ${INSTALL_PREFIX}
HPCX_PATH=${INSTALL_PREFIX}/${HPCX_FOLDER}
$COMMON_DIR/write_component_version.sh "HPCX" $HPCX_VERSION

# rebuild HPCX with PMIx
# PMIX is installed from AZL 3.0 PMC to default path
${HPCX_PATH}/utils/hpcx_rebuild.sh --with-hcoll --ompi-extra-config "--with-pmix --enable-orterun-prefix-by-default"
cp -r ${HPCX_PATH}/ompi/tests ${HPCX_PATH}/hpcx-rebuild

# exclude ucx from updates
sed -i "$ s/$/ ucx*/" /etc/dnf/dnf.conf

# Setup module files for MPIs
mkdir -p /usr/share/Modules/modulefiles/mpi/

# HPC-X
cat << EOF >> /usr/share/Modules/modulefiles/mpi/hpcx-${HPCX_VERSION}
#%Module 1.0
#
#  HPCx ${HPCX_VERSION}
#
conflict        mpi
module load ${HPCX_PATH}/modulefiles/hpcx
EOF

# HPC-X with PMIX
cat << EOF >> /usr/share/Modules/modulefiles/mpi/hpcx-pmix-${HPCX_VERSION}
#%Module 1.0
#
#  HPCx ${HPCX_VERSION}
#
conflict        mpi
module load ${HPCX_PATH}/modulefiles/hpcx-rebuild
EOF

# Create symlinks for modulefiles
ln -s /usr/share/Modules/modulefiles/mpi/hpcx-${HPCX_VERSION} /usr/share/Modules/modulefiles/mpi/hpcx
ln -s /usr/share/Modules/modulefiles/mpi/hpcx-pmix-${HPCX_VERSION} /usr/share/Modules/modulefiles/mpi/hpcx-pmix

HCOLL_PATH=${HPCX_PATH}/hcoll
UCX_PATH=${HPCX_PATH}/ucx

# MVAPICH2
mvapich2_metadata=$(get_component_config "mvapich2")
MVAPICH2_VERSION=$(jq -r '.version' <<< $mvapich2_metadata)
MVAPICH2_SHA256=$(jq -r '.sha256' <<< $mvapich2_metadata)
MVAPICH2_DOWNLOAD_URL="http://mvapich.cse.ohio-state.edu/download/mvapich/mv2/mvapich2-${MVAPICH2_VERSION}.tar.gz"
TARBALL=$(basename $MVAPICH2_DOWNLOAD_URL)
MVAPICH2_FOLDER=$(basename $MVAPICH2_DOWNLOAD_URL .tar.gz)

$COMMON_DIR/download_and_verify.sh $MVAPICH2_DOWNLOAD_URL $MVAPICH2_SHA256
tar -xvf ${TARBALL}
cd ${MVAPICH2_FOLDER}
# gfortran 11.2.0
# configure: error: The Fortran compiler gfortran will not compile files that call
# the same routine with arguments of different types.
./configure FFLAGS=-fallow-argument-mismatch --prefix=${INSTALL_PREFIX}/mvapich2-${MVAPICH2_VERSION} --enable-g=none --enable-fast=yes && make -j$(nproc) && make install
cd ..
$COMMON_DIR/write_component_version.sh "MVAPICH2" ${MVAPICH2_VERSION}


# Install Open MPI
ompi_metadata=$(get_component_config "ompi")
OMPI_VERSION=$(jq -r '.version' <<< $ompi_metadata)
OMPI_SHA256=$(jq -r '.sha256' <<< $ompi_metadata)
OMPI_DOWNLOAD_URL=$(jq -r '.url' <<< $ompi_metadata)
TARBALL=$(basename $OMPI_DOWNLOAD_URL)
OMPI_FOLDER=$(basename $OMPI_DOWNLOAD_URL .tar.gz)

$COMMON_DIR/download_and_verify.sh $OMPI_DOWNLOAD_URL $OMPI_SHA256
tar -xvf $TARBALL
cd $OMPI_FOLDER
# ld can't see libocoms without hcoll lib path. Note: I couldn't get LDFLAGS to work
./configure LD_LIBRARY_PATH=$LD_LIBRARY_PATH:${HCOLL_PATH}/lib --prefix=${INSTALL_PREFIX}/openmpi-${OMPI_VERSION} --with-ucx=${UCX_PATH} --with-hcoll=${HCOLL_PATH} --enable-mpirun-prefix-by-default --with-platform=contrib/platform/mellanox/optimized && make -j$(nproc) && make install
cd ..
$COMMON_DIR/write_component_version.sh "OMPI" ${OMPI_VERSION}

# exclude openmpi, perftest from updates
sed -i "$ s/$/ openmpi perftest/" /etc/dnf/dnf.conf

# Install Intel MPI
impi_metadata=$(get_component_config "impi")
IMPI_VERSION=$(jq -r '.version' <<< $impi_metadata)
IMPI_SHA256=$(jq -r '.sha256' <<< $impi_metadata)
IMPI_DOWNLOAD_URL=$(jq -r '.url' <<< $impi_metadata)
IMPI_OFFLINE_INSTALLER=$(basename $IMPI_DOWNLOAD_URL)

$COMMON_DIR/download_and_verify.sh $IMPI_DOWNLOAD_URL $IMPI_SHA256
bash $IMPI_OFFLINE_INSTALLER -s -a -s --eula accept

impi_2021_version=${IMPI_VERSION:0:-2}
mv ${INSTALL_PREFIX}/intel/oneapi/mpi/${impi_2021_version}/etc/modulefiles/mpi ${INSTALL_PREFIX}/intel/oneapi/mpi/${impi_2021_version}/etc/modulefiles/impi
$COMMON_DIR/write_component_version.sh "IMPI" ${IMPI_VERSION}

# Setup module files for MPIs
mkdir -p /usr/share/Modules/modulefiles/mpi/

# MVAPICH2
cat << EOF >> /usr/share/Modules/modulefiles/mpi/mvapich2-${MVAPICH2_VERSION}
#%Module 1.0
#
#  MVAPICH2 ${MVAPICH2_VERSION}
#
conflict        mpi
module load ${GCC_VERSION}
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

#IntelMPI-v2021
cat << EOF >> /usr/share/Modules/modulefiles/mpi/impi_${impi_2021_version}
#%Module 1.0
#
#  Intel MPI ${impi_2021_version}
#
conflict        mpi
module load /opt/intel/oneapi/mpi/${impi_2021_version}/etc/modulefiles/impi/${impi_2021_version}
setenv          MPI_BIN         /opt/intel/oneapi/mpi/${impi_2021_version}/bin
setenv          MPI_INCLUDE     /opt/intel/oneapi/mpi/${impi_2021_version}/include
setenv          MPI_LIB         /opt/intel/oneapi/mpi/${impi_2021_version}/lib
setenv          MPI_MAN         /opt/intel/oneapi/mpi/${impi_2021_version}/man
setenv          MPI_HOME        /opt/intel/oneapi/mpi/${impi_2021_version}
EOF

# Create symlinks for modulefiles
ln -s /usr/share/Modules/modulefiles/mpi/mvapich2-${MVAPICH2_VERSION} /usr/share/Modules/modulefiles/mpi/mvapich2
ln -s /usr/share/Modules/modulefiles/mpi/openmpi-${OMPI_VERSION} /usr/share/Modules/modulefiles/mpi/openmpi
ln -s /usr/share/Modules/modulefiles/mpi/impi_${impi_2021_version} /usr/share/Modules/modulefiles/mpi/impi-2021

# cleanup downloaded tarballs and other installation files/folders
rm -rf *.tar.gz *offline.sh
rm -rf -- */

# cleanup downloaded tarball for HPC-x
rm -rf *.tbz

# # Setup permissions
# chmod -R 755 /usr/share/Modules/modulefiles/mpi/