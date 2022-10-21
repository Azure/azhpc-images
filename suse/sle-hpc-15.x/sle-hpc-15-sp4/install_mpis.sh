#!/bin/bash
set -ex

# SLE HPC 15 SP4 comes with three different implementation of the Message Passing Interface (MPI) standard are provided standard with the HPC module:
#   Open MPI 4 (and version 3)
#   MVAPICH2
#   MPICH 4
#   MPICH-ofi 4.0.1
#   openblas
#   Intel MPI Benchmarks
# These packages have been built with full environment module support (LMOD).
# PLEASE have a look at our documentation
# https://documentation.suse.com/sle-hpc/15-SP4/single-html/hpc-guide/#sec-compute-lib

# https://docs.nvidia.com/networking/category/hpcx
# https://docs.nvidia.com/networking/display/HPCXv28

# SUSE uses lmod
MODULE_FILES_DIRECTORY=/usr/share/lmod/modulefiles

# Load gcc
set CC=/usr/bin/gcc
set GCC=/usr/bin/gcc

#
INSTALL_PREFIX=/opt
#
# HPC-X v2.12
HPCX_VERSION="v2.12"
# pls accept the EULA
HPCX_DOWNLOAD_URL=https://content.mellanox.com/hpc/hpc-x/v2.12/hpcx-v2.12-gcc-inbox-suse15.4-cuda11-gdrcopy2-nccl2.12-x86_64.tbz
TARBALL=$(basename ${HPCX_DOWNLOAD_URL})
HPCX_FOLDER=$(basename ${HPCX_DOWNLOAD_URL} .tbz)

# the web page said checksum is md5 but in reality is sha256
$COMMON_DIR/download_and_verify.sh ${HPCX_DOWNLOAD_URL} "bc315d3b485d13c97cd174ef5c9cba5c2fa1fbc3e5175f96f1a406a6c0699bdb"
tar -xvf ${TARBALL}
mv ${HPCX_FOLDER} ${INSTALL_PREFIX}
HPCX_PATH=${INSTALL_PREFIX}/${HPCX_FOLDER}
$COMMON_DIR/write_component_version.sh "HPCX" $HPCX_VERSION

# Enable Sharpd
#${HPCX_PATH}/sharp/sbin/sharp_daemons_setup.sh -s -d sharpd
#systemctl enable sharpd
#systemctl start sharpd

# MVAPICH2
# MV2_VERSION="2.3.6"
zypper install mvapich2-gnu-hpc
MV2_VERSION=$(rpm -q  --qf="%{VERSION}" mvapich2-gnu-hpc)
$COMMON_DIR/write_component_version.sh "MVAPICH2" ${MV2_VERSION}

# OpenMPI 4
# OMPI_VERSION="4.1.1"
zypper install openmpi4-gnu-hpc  libopenmpi4-gnu-hpc
OMPI_VERSION=$(rpm -q  --qf="%{VERSION}" openmpi4-gnu-hpc)
$COMMON_DIR/write_component_version.sh "OMPI" ${OMPI_VERSION}

# Intel MPI 2021
# IMPI_2021_VERSION="2021.7.0"
zypper install -y -l intel-oneapi-mpi
IMPI_2021_VERSION=$(rpm -q  --qf="%{VERSION}" intel-oneapi-mpi)
# Create modulesfiles
/opt/intel/oneapi/modulefiles-setup.sh
$COMMON_DIR/write_component_version.sh "IMPI_2021" ${IMPI_2021_VERSION}

#
# # Setup module files for MPIs
#

# mkdir -p /usr/share/Modules/modulefiles/mpi/
mkdir -p $MODULE_FILES_DIRECTORY/mpi/

#
# # HPC-X
cat << EOF >> $MODULE_FILES_DIRECTORY/mpi/hpcx-${HPCX_VERSION}
#%Module 1.0
#
#  HPCx ${HPCX_VERSION}
#
#module-whatis "Description: Mellanox HPC-X™ Software Toolkit"
set version ${HPCX_VERSION}
conflict mpi
module use ${HPCX_PATH}/modulefiles
module load hpcx
EOF

# MVAPICH2 -> already provided by suse package
# /usr/share/lmod/moduledeps/gnu-7/mvapich2/2.3.6
#
ln -s /usr/share/lmod/moduledeps/gnu-7/mvapich2/2.3.6 ${MODULE_FILES_DIRECTORY}/mpi/mvapich2-${MV2_VERSION}
#cat << EOF >> ${MODULE_FILES_DIRECTORY}/mvapich2-${MV2_VERSION}
##%Module 1.0
##
##  MVAPICH2 ${MV2_VERSION}
##
#conflict        mpi
#prepend-path    PATH            /opt/mvapich2-${MV2_VERSION}/bin
#prepend-path    LD_LIBRARY_PATH /opt/mvapich2-${MV2_VERSION}/lib
#prepend-path    MANPATH         /opt/mvapich2-${MV2_VERSION}/share/man
#setenv          MPI_BIN         /opt/mvapich2-${MV2_VERSION}/bin
#setenv          MPI_INCLUDE     /opt/mvapich2-${MV2_VERSION}/include
#setenv          MPI_LIB         /opt/mvapich2-${MV2_VERSION}/lib
#setenv          MPI_MAN         /opt/mvapich2-${MV2_VERSION}/share/man
#setenv          MPI_HOME        /opt/mvapich2-${MV2_VERSION}
#EOF

# OpenMPI -> already provided by suse package
ln -s /usr/share/lmod/moduledeps/gnu-7/openmpi/4.1.1 ${MODULE_FILES_DIRECTORY}/mpi/openmpi-${OMPI_VERSION}
#
#cat << EOF >> ${MODULE_FILES_DIRECTORY}/openmpi-${OMPI_VERSION}
##%Module 1.0
##
##  OpenMPI ${OMPI_VERSION}
##
#conflict        mpi
#prepend-path    PATH            /opt/openmpi-${OMPI_VERSION}/bin
#prepend-path    LD_LIBRARY_PATH /opt/openmpi-${OMPI_VERSION}/lib
#prepend-path    MANPATH         /opt/openmpi-${OMPI_VERSION}/share/man
#setenv          MPI_BIN         /opt/openmpi-${OMPI_VERSION}/bin
#setenv          MPI_INCLUDE     /opt/openmpi-${OMPI_VERSION}/include
#setenv          MPI_LIB         /opt/openmpi-${OMPI_VERSION}/lib
#setenv          MPI_MAN         /opt/openmpi-${OMPI_VERSION}/share/man
#setenv          MPI_HOME        /opt/openmpi-${OMPI_VERSION}
#EOF

# Intel 2021
# the oneapi has its own modulefiles
#
#cat << EOF >> ${MODULE_FILES_DIRECTORY}/impi_${IMPI_2021_VERSION}
##%Module 1.0
##
##  Intel MPI ${IMPI_2021_VERSION}
##
#conflict        mpi
#module load /opt/intel/oneapi/mpi/${IMPI_2021_VERSION}/modulefiles/impi
#setenv          MPI_BIN         /opt/intel/oneapi/mpi/${IMPI_2021_VERSION}/bin
#setenv          MPI_INCLUDE     /opt/intel/oneapi/mpi/${IMPI_2021_VERSION}/include
#setenv          MPI_LIB         /opt/intel/oneapi/mpi/${IMPI_2021_VERSION}/lib
#setenv          MPI_MAN         /opt/intel/oneapi/mpi/${IMPI_2021_VERSION}/man
#setenv          MPI_HOME        /opt/intel/oneapi/mpi/${IMPI_2021_VERSION}
#EOF

#
# # Create symlinks for modulefiles
ln -s ${MODULE_FILES_DIRECTORY}/mpi/hpcx-${HPCX_VERSION} ${MODULE_FILES_DIRECTORY}/mpi/hpcx
ln -s ${MODULE_FILES_DIRECTORY}/mpi/mvapich2-${MV2_VERSION} ${MODULE_FILES_DIRECTORY}/mpi/mvapich2
ln -s ${MODULE_FILES_DIRECTORY}/mpi/openmpi-${OMPI_VERSION} ${MODULE_FILES_DIRECTORY}/mpi/openmpi
# add the intel genereated modulefiles to the path
ln -s /opt/intel/oneapi/mpi/${IMPI_2021_VERSION}/modulefiles/mpi ${MODULE_FILES_DIRECTORY}/mpi/impi-2021