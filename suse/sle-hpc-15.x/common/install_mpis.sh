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


# Load gcc
set CC=/usr/bin/gcc
set GCC=/usr/bin/gcc

#
INSTALL_PREFIX=/opt

#
# HPC-X
TARBALL=$(basename ${HPCX_DOWNLOAD_URL})
HPCX_FOLDER=$(basename ${HPCX_DOWNLOAD_URL} .tbz)
# the web page said checksum is md5 but in reality is sha256
$COMMON_DIR/download_and_verify.sh ${HPCX_DOWNLOAD_URL} ${HPCX_CHKSUM}
tar -xvf ${TARBALL}
mv ${HPCX_FOLDER} ${INSTALL_PREFIX}
HPCX_PATH=${INSTALL_PREFIX}/${HPCX_FOLDER}
$COMMON_DIR/write_component_version.sh "HPCX" $HPCX_VERSION

# Enable Sharpd
#${HPCX_PATH}/sharp/sbin/sharp_daemons_setup.sh -s -d sharpd
#systemctl enable sharpd
#systemctl start sharpd

# MVAPICH2
# shipped with SLE HPC
zypper install -y mvapich2-gnu-hpc
MV2_VERSION=$(rpm -q  --qf="%{VERSION}" mvapich2-gnu-hpc)
$COMMON_DIR/write_component_version.sh "MVAPICH2" ${MV2_VERSION}

# OpenMPI 4
# shipped with SLE HPC
zypper install -y ${OMPI}-gnu-hpc  lib${OMPI}-gnu-hpc
OMPI_VERSION=$(rpm -q  --qf="%{VERSION}" ${OMPI}-gnu-hpc)
$COMMON_DIR/write_component_version.sh "OMPI" ${OMPI_VERSION}

# Intel MPI
# as there are more versions in the repos we need to select one
# instead of always get the newest
zypper install -y -l intel-oneapi-mpi = ${INTEL_ONE_MPI_VERSION}
# Create modulesfiles
/opt/intel/oneapi/modulefiles-setup.sh
$COMMON_DIR/write_component_version.sh "IMPI_${IMPI_MAJOR}" ${INTEL_ONE_MPI_VERSION}

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

# MVAPICH2 -> already provided by suse package, build with gcc7
# e.g. /usr/share/lmod/moduledeps/gnu-7/mvapich2/2.3.6
# libraries are build against gnu-7 and not gnu-11, so we need to have the path hardcoded to gnu-7
#
ln -s /usr/share/lmod/moduledeps/gnu-7/mvapich2/${MV2_VERSION} ${MODULE_FILES_DIRECTORY}/mpi/mvapich2-${MV2_VERSION}

# OpenMPI -> already provided by suse package, build with gcc7
ln -s /usr/share/lmod/moduledeps/gnu-7/openmpi/${OMPI_VERSION} ${MODULE_FILES_DIRECTORY}/mpi/openmpi-${OMPI_VERSION}

# Intel oneAPI
# the oneapi provides its own modulefiles
ln -s $INTELLIBS/mpi/${INTEL_ONE_MPI_VERSION}/modulefiles/mpi ${MODULE_FILES_DIRECTORY}/mpi/impi-${IMPI_MAJOR}


# # Create symlinks for modulefiles
ln -s ${MODULE_FILES_DIRECTORY}/mpi/hpcx-${HPCX_VERSION} ${MODULE_FILES_DIRECTORY}/mpi/hpcx
ln -s ${MODULE_FILES_DIRECTORY}/mpi/mvapich2-${MV2_VERSION} ${MODULE_FILES_DIRECTORY}/mpi/mvapich2
ln -s ${MODULE_FILES_DIRECTORY}/mpi/openmpi-${OMPI_VERSION} ${MODULE_FILES_DIRECTORY}/mpi/openmpi

# cleanup downloaded tarballs and other installation files/folders
rm -rf *.tar.gz *offline.sh
rm -rf -- */
