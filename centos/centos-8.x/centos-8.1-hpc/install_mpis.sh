#!/bin/bash
set -ex

# Load gcc
GCC_VERSION=gcc-9.2.0
export PATH=/opt/${GCC_VERSION}/bin:$PATH
export LD_LIBRARY_PATH=/opt/${GCC_VERSION}/lib64:$LD_LIBRARY_PATH
set CC=/opt/${GCC_VERSION}/bin/gcc
set GCC=/opt/${GCC_VERSION}/bin/gcc


INSTALL_PREFIX=/opt

# HPC-X v2.7.0
HPCX_VERSION="v2.7.0"
HPCX_DOWNLOAD_URL=https://azhpcstor.blob.core.windows.net/azhpc-images-store/hpcx-v2.7.0-gcc9.2.0-MLNX_OFED_LINUX-5.1-0.6.6.0-redhat8.1-x86_64.tbz
$COMMON_DIR/download_and_verify.sh $HPCX_DOWNLOAD_URL "0861622335f67b9f84556bc6a7d8758aa373943d69b49175526b99c53c576732"
tar -xvf hpcx-${HPCX_VERSION}-gcc9.2.0-MLNX_OFED_LINUX-5.1-0.6.6.0-redhat8.1-x86_64.tbz
mv hpcx-${HPCX_VERSION}-gcc-MLNX_OFED_LINUX-5.1-0.6.6.0-redhat8.1-x86_64 ${INSTALL_PREFIX}
HPCX_PATH=${INSTALL_PREFIX}/hpcx-${HPCX_VERSION}-gcc-MLNX_OFED_LINUX-5.1-0.6.6.0-redhat8.1-x86_64

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
../../common/install_mpis.sh ${GCC_VERSION} ${HPCX_PATH}
