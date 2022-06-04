#!/bin/bash
set -ex

# Load gcc
GCC_VERSION=gcc-9.2.0
export PATH=/opt/${GCC_VERSION}/bin:$PATH
export LD_LIBRARY_PATH=/opt/${GCC_VERSION}/lib64:$LD_LIBRARY_PATH
set CC=/opt/${GCC_VERSION}/bin/gcc
set GCC=/opt/${GCC_VERSION}/bin/gcc


INSTALL_PREFIX=/opt

# HPC-X v2.11.0 - sharpd daemon removed in 2.10
HPCX_VERSION="v2.11.0"
HPCX_DOWNLOAD_URL=https://content.mellanox.com/hpc/hpc-x/v2.11/hpcx-v2.11-gcc-MLNX_OFED_LINUX-5-suse15.3-cuda11-gdrcopy2-nccl2.11-x86_64.tbz
TARBALL=$(basename ${HPCX_DOWNLOAD_URL})
HPCX_FOLDER=$(basename ${HPCX_DOWNLOAD_URL} .tbz)

if ![[ -f ${TARBALL} ]]; then
    $COMMON_DIR/download_and_verify.sh $HPCX_DOWNLOAD_URL "00e8bb436c63ca1ee89304b9fd3eb03dae2020d377ca0e7238643018921ba351"
    tar -xvf ${TARBALL}
fi

if ![[ -d ${INSTALL_PREFIX}/${HPCX_FOLDER} ]]; then
    mv ${HPCX_FOLDER} ${INSTALL_PREFIX}
fi
HPCX_PATH=${INSTALL_PREFIX}/${HPCX_FOLDER}

# Setup module files for MPIs
mkdir -p ${MODULE_FILES_ROOT}/mpi

# HPC-X
cat << EOF >> ${MODULE_FILES_ROOT}/hpcx-${HPCX_VERSION}
#%Module 1.0
#
#  HPCx ${HPCX_VERSION}
#
conflict        mpi
module load ${HPCX_PATH}/modulefiles/hpcx
EOF

# Create symlinks for modulefiles
ln -s ${MODULE_FILES_ROOT}/mpi/hpcx-${HPCX_VERSION} ${MODULE_FILES_ROOT}/mpi/hpcx

# Install platform independent MPIs
../../common/install_mpis.sh
