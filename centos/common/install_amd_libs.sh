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
FFTW_DOWNLOAD_URL=https://github.com/amd/amd-fftw/releases/download/2.2/aocl-fftw-linux-gcc-2.2-4.tar.gz
$COMMON_DIR/download_and_verify.sh $FFTW_DOWNLOAD_URL "06afb759e3419a0ea7ba9b08dd217d94d75e4bbb76e847345a1fa75af64fa60b"
tar -xvf aocl-fftw-linux-gcc-2.2-4.tar.gz
cp -r amd-fftw ${INSTALL_PREFIX}/fftw


# AMD libflame
LIBFLAME_DOWNLOAD_URL=https://github.com/amd/libflame/releases/download/2.2/aocl-libflame-linux-gcc-2.2-4.tar.gz
$COMMON_DIR/download_and_verify.sh $LIBFLAME_DOWNLOAD_URL "13e3eb9e174ff3c9f44f33e8c9b2bf9d7513ea5840109a4d37a2fa4f769f3451"
tar -xvf aocl-libflame-linux-gcc-2.2-4.tar.gz
cp -r amd-libflame ${INSTALL_PREFIX}/libflame


# AMD blis & AMD blis-mt
BLIS_DOWNLOAD_URL=https://github.com/amd/blis/releases/download/2.2/aocl-blis-linux-gcc-2.2-4.tar.gz
$COMMON_DIR/download_and_verify.sh $BLIS_DOWNLOAD_URL "e9bd8bc808a3cb8b84ff46f1f3c12c214c2699c80b82d43e3bedf24b9bb79ac6"
tar -xvf aocl-blis-linux-gcc-2.2-4.tar.gz
cp -r amd-blis ${INSTALL_PREFIX}/blis

FFTW_VERSION="2.2"
LIBFLAME_VERSION="2.2"
BLIS_VERSION="2.2"

# Setup module files for AMD Libraries
mkdir -p /usr/share/Modules/modulefiles/amd/

# fftw
cat << EOF >> /usr/share/Modules/modulefiles/amd/fftw-${FFTW_VERSION}
#%Module 1.0
#
#  fftw
#
module load ${GCC_VERSION}
prepend-path    LD_LIBRARY_PATH   ${INSTALL_PREFIX}/fftw/lib
setenv          AMD_FFTW_INCLUDE  ${INSTALL_PREFIX}/fftw/include
EOF

# libflame
cat << EOF >> /usr/share/Modules/modulefiles/amd/libflame-${LIBFLAME_VERSION}
#%Module 1.0
#
#  libflame
#
module load ${GCC_VERSION}
prepend-path    LD_LIBRARY_PATH       ${INSTALL_PREFIX}/libflame/lib 
setenv          AMD_LIBFLAME_INCLUDE  ${INSTALL_PREFIX}/libflame/include
EOF

# blis & blis-mt
cat << EOF >> /usr/share/Modules/modulefiles/amd/blis-${BLIS_VERSION}
#%Module 1.0
#
#  blis
#
module load ${GCC_VERSION}
prepend-path    LD_LIBRARY_PATH   ${INSTALL_PREFIX}/blis/lib
setenv          AMD_BLIS_INCLUDE  ${INSTALL_PREFIX}/blis/include
EOF

# Create symlinks for modulefiles
ln -s /usr/share/Modules/modulefiles/amd/fftw-${FFTW_VERSION} /usr/share/Modules/modulefiles/amd/fftw
ln -s /usr/share/Modules/modulefiles/amd/libflame-${LIBFLAME_VERSION} /usr/share/Modules/modulefiles/amd/libflame
ln -s /usr/share/Modules/modulefiles/amd/blis-${BLIS_VERSION} /usr/share/Modules/modulefiles/amd/blis
