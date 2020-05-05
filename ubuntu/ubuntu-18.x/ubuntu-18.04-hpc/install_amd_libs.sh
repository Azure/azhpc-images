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
FFTW_DOWNLOAD_URL=https://github.com/amd/amd-fftw/releases/download/2.0/aocl-fftw-ubuntu-2.0.tar.gz
$COMMON_DIR/download_and_verify.sh $FFTW_DOWNLOAD_URL "306b7e68faaef6acd4970b91b3ac8ea43577b5dbe6756b2327fe8a7daa29a71f"
tar -xvf aocl-fftw-ubuntu-2.0.tar.gz
cp -r amd-fftw ${INSTALL_PREFIX}/fftw


# AMD libflame
LIBFLAME_DOWNLOAD_URL=https://github.com/amd/libflame/releases/download/2.0/aocl-libflame-ubuntu-2.0.tar.gz
$COMMON_DIR/download_and_verify.sh $LIBFLAME_DOWNLOAD_URL "8a39caae79de8065d6ba89008ca516e46ce1d60db346d993f6aa170945eaf051"
tar -xvf aocl-libflame-ubuntu-2.0.tar.gz
cp -r amd-libflame ${INSTALL_PREFIX}/libflame


# AMD blis
BLIS_DOWNLOAD_URL=https://github.com/amd/blis/releases/download/2.0/aocl-blis-ubuntu-2.0.tar.gz
$COMMON_DIR/download_and_verify.sh $BLIS_DOWNLOAD_URL "89d947b3879ad9bc0d03c6bafcc0340c1fb74489cb4768a006010585a3736990"
tar -xvf aocl-blis-ubuntu-2.0.tar.gz
cp -r amd-blis ${INSTALL_PREFIX}/blis


# AMD blis-mt
BLIS_MT_DOWNLOAD_URL=https://github.com/amd/blis/releases/download/2.0/aocl-blis-mt-ubuntu-2.0.tar.gz
$COMMON_DIR/download_and_verify.sh $BLIS_MT_DOWNLOAD_URL "f8fe674a7992ede058cde9e1551627dba10300dbcad3b216bbca34ad8718291a"
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
