#!/bin/bash
set -ex

# Load gcc
GCC_VERSION=gcc-9.2.0
export PATH=/opt/${GCC_VERSION}/bin:$PATH
export LD_LIBRARY_PATH=/opt/${GCC_VERSION}/lib64:$LD_LIBRARY_PATH
set CC=/opt/${GCC_VERSION}/bin/gcc
set GCC=/opt/${GCC_VERSION}/bin/gcc


INSTALL_PREFIX=/opt

# HPC-X v2.7.4
HPCX_VERSION="v2.7.4"
HPCX_DOWNLOAD_URL=https://azhpcstor.blob.core.windows.net/azhpc-images-store/hpcx-v2.8.0-gcc-MLNX_OFED_LINUX-5.2-1.0.4.0-redhat8.3-x86_64.tbz
TARBALL=$(basename ${HPCX_DOWNLOAD_URL})
HPCX_FOLDER=$(basename ${HPCX_DOWNLOAD_URL} .tbz)

$COMMON_DIR/download_and_verify.sh $HPCX_DOWNLOAD_URL "ee1b0f3fe8d295ae662cd08794a890135b4014b9b3e8efa3f00aafe4678bae9c"
tar -xvf ${TARBALL}
mv ${HPCX_FOLDER} ${INSTALL_PREFIX}
HPCX_PATH=${INSTALL_PREFIX}/${HPCX_FOLDER}

# Enable Sharpd
${HPCX_PATH}/sharp/sbin/sharp_daemons_setup.sh -s -d sharpd
systemctl enable sharpd
systemctl start sharpd

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
