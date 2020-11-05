#!/bin/bash
set -ex

INSTALL_PREFIX=/opt/amd
mkdir -p ${INSTALL_PREFIX}

AOCL_VERSION="2.2.1"
AOCL_DOWNLOAD_URL="https://azhpcstor.blob.core.windows.net/azhpc-images-store/aocl-linux-aocc-2.2.1_centos8.tar.gz"
$COMMON_DIR/download_and_verify.sh $AOCL_DOWNLOAD_URL "cbe5afbdc241047a9d8814b5557be429aa0d9d2b83408eca8244e1ab9c8e2c87"

TARBALL=$(basename ${AOCL_DOWNLOAD_URL})
tar -xvf ${TARBALL}
cd aocl-linux-aocc-${AOCL_VERSION}_centos8

./install.sh -t amd -l blis fftw libflame
cp -r amd/${AOCL_VERSION}_centos8/* ${INSTALL_PREFIX}
cd .. && rm -rf aocl-linux-aocc-${AOCL_VERSION}_centos8

# Setup module files for AMD Libraries
mkdir -p /usr/share/Modules/modulefiles/amd/

# fftw
cat << EOF >> /usr/share/Modules/modulefiles/amd/aocl-${AOCL_VERSION}
#%Module 1.0
#
#  AOCL
#
prepend-path    LD_LIBRARY_PATH   ${INSTALL_PREFIX}/lib
setenv          AMD_FFTW_INCLUDE  ${INSTALL_PREFIX}/include
EOF

# Create symlinks for modulefiles
ln -s /usr/share/Modules/modulefiles/amd/aocl-${AOCL_VERSION} /usr/share/Modules/modulefiles/amd/aocl
