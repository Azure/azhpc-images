#!/bin/bash
set -ex

# Load gcc
GCC_VERSION=gcc-9.2.0
export PATH=/opt/${GCC_VERSION}/bin:$PATH
export LD_LIBRARY_PATH=/opt/${GCC_VERSION}/lib64:$LD_LIBRARY_PATH
set CC=/opt/${GCC_VERSION}/bin/gcc
set GCC=/opt/${GCC_VERSION}/bin/gcc


INSTALL_PREFIX=/opt

# HPC-X v2.7.2
HPCX_VERSION="v2.7.2"
HPCX_DOWNLOAD_URL=https://azhpcstor.blob.core.windows.net/azhpc-images-store/hpcx-v2.7.2-gcc-MLNX_OFED_LINUX-5.1-2.4.6.0-redhat7.7-x86_64.tbz
TARBALL=$(basename ${HPCX_DOWNLOAD_URL})
HPCX_FOLDER=$(basename ${HPCX_DOWNLOAD_URL} .tbz)

$COMMON_DIR/download_and_verify.sh $HPCX_DOWNLOAD_URL "e038a037b1a42e0386f4f99987680f60b931c1ddaceeb168f0b20b31ce4b8554"
tar -xvf ${TARBALL}
mv ${HPCX_FOLDER} ${INSTALL_PREFIX}
HPCX_PATH=${INSTALL_PREFIX}/${HPCX_FOLDER}

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

# Create symlinks for modulefiles
ln -s /usr/share/Modules/modulefiles/mpi/hpcx-${HPCX_VERSION} /usr/share/Modules/modulefiles/mpi/hpcx

# Install platform independent MPIs
../common/install_mpis.sh ${GCC_VERSION} ${HPCX_PATH}

