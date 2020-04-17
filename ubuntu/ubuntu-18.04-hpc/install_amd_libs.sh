#!/bin/bash
set -ex

# Load gcc
GCC_VERSION=gcc-9.2.0
export PATH=/opt/${GCC_VERSION}/bin:$PATH
export LD_LIBRARY_PATH=/opt/${GCC_VERSION}/lib64:$LD_LIBRARY_PATH
set CC=/opt/${GCC_VERSION}/bin/gcc
set GCC=/opt/${GCC_VERSION}/bin/gcc

INSTALL_PREFIX=/opt/amd
mkdir -p ${INSTALL_PREFIX}

# AMD FFTW
wget https://github.com/amd/amd-fftw/releases/download/2.0/aocl-fftw-ubuntu-2.0.tar.gz
tar -xvf aocl-fftw-ubuntu-2.0.tar.gz
cp -r amd-fftw ${INSTALL_PREFIX}/fftw


# AMD libflame
wget https://github.com/amd/libflame/releases/download/2.0/aocl-libflame-ubuntu-2.0.tar.gz
tar -xvf aocl-libflame-ubuntu-2.0.tar.gz
cp -r amd-libflame ${INSTALL_PREFIX}/libflame


# AMD blis 
wget https://github.com/amd/blis/releases/download/2.0/aocl-blis-ubuntu-2.0.tar.gz
tar -xvf aocl-blis-ubuntu-2.0.tar.gz
cp -r amd-blis ${INSTALL_PREFIX}/blis


# AMD blis-mt
wget https://github.com/amd/blis/releases/download/2.0/aocl-blis-mt-ubuntu-2.0.tar.gz
tar -xvf aocl-blis-mt-ubuntu-2.0.tar.gz
cp -r amd-blis-mt ${INSTALL_PREFIX}/blis-mt

FFTW_VERSION="2.0"
LIBFLAME_VERSION="2.0"
BLIS_VERSION="2.0"
BLIS_MT_VERSION="2.0"

# Setup module files for AMD Libraries
MODULE_FILES_DIRECTORY=/usr/share/modules/modulefiles/amd
mkdir -p ${MODULE_FILES_DIRECTORY}

# fftw
cat << EOF >> ${MODULE_FILES_DIRECTORY}/fftw-${FFTW_VERSION}
#%Module 1.0
#
#  fftw
#
module load ${GCC_VERSION}
prepend-path    LD_LIBRARY_PATH   ${INSTALL_PREFIX}/fftw/lib
setenv          AMD_FFTW_INCLUDE  ${INSTALL_PREFIX}/fftw/include
EOF

# libflame
cat << EOF >> ${MODULE_FILES_DIRECTORY}/libflame-${LIBFLAME_VERSION}
#%Module 1.0
#
#  libflame
#
module load ${GCC_VERSION}
prepend-path    LD_LIBRARY_PATH       ${INSTALL_PREFIX}/libflame/lib
setenv          AMD_LIBFLAME_INCLUDE  ${INSTALL_PREFIX}/libflame/include
EOF

# blis
cat << EOF >> ${MODULE_FILES_DIRECTORY}/blis-${BLIS_VERSION}
#%Module 1.0
#
#  blis
#
module load ${GCC_VERSION}
prepend-path    LD_LIBRARY_PATH   ${INSTALL_PREFIX}/blis/lib
setenv          AMD_BLIS_INCLUDE  ${INSTALL_PREFIX}/blis/include
EOF

# blis-mt
cat << EOF >> ${MODULE_FILES_DIRECTORY}/blis-mt-${BLIS_MT_VERSION}
#%Module 1.0
#
#  blis-mt
#
module load ${GCC_VERSION}
prepend-path    LD_LIBRARY_PATH      ${INSTALL_PREFIX}/blis-mt/lib
setenv          AMD_BLIS_MT_INCLUDE  ${INSTALL_PREFIX}/blis-mt/include
EOF

# Create symlinks for modulefiles
ln -s ${MODULE_FILES_DIRECTORY}/fftw-${FFTW_VERSION} ${MODULE_FILES_DIRECTORY}/fftw
ln -s ${MODULE_FILES_DIRECTORY}/libflame-${LIBFLAME_VERSION} ${MODULE_FILES_DIRECTORY}/libflame
ln -s ${MODULE_FILES_DIRECTORY}/blis-${BLIS_VERSION} ${MODULE_FILES_DIRECTORY}/blis
ln -s ${MODULE_FILES_DIRECTORY}/blis-mt-${BLIS_MT_VERSION} ${MODULE_FILES_DIRECTORY}/blis-mt
