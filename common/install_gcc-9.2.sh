#!/bin/bash
set -ex

# Install gcc 9.2
GMP_DOWNLOAD_URL=http://gcc.gnu.org/pub/gcc/infrastructure/gmp-6.1.0.tar.bz2
$COMMON_DIR/download_and_verify.sh $GMP_DOWNLOAD_URL "498449a994efeba527885c10405993427995d3f86b8768d8cdf8d9dd7c6b73e8"
tar -xvf gmp-6.1.0.tar.bz2
cd ./gmp-6.1.0
./configure && make -j$(nproc) &&  make install
cd ..

MPFR_DOWNLOAD_URL=http://gcc.gnu.org/pub/gcc/infrastructure/mpfr-3.1.4.tar.bz2
$COMMON_DIR/download_and_verify.sh $MPFR_DOWNLOAD_URL "d3103a80cdad2407ed581f3618c4bed04e0c92d1cf771a65ead662cc397f7775"
tar -xvf mpfr-3.1.4.tar.bz2
cd mpfr-3.1.4
./configure && make -j$(nproc) &&  make install
cd ..

MPC_DOWNLOAD_URL=http://gcc.gnu.org/pub/gcc/infrastructure/mpc-1.0.3.tar.gz
$COMMON_DIR/download_and_verify.sh $MPC_DOWNLOAD_URL "617decc6ea09889fb08ede330917a00b16809b8db88c29c31bfbb49cbf88ecc3"
tar -xvf mpc-1.0.3.tar.gz
cd mpc-1.0.3
./configure && make -j$(nproc) &&  make install
cd ..

# install gcc 9.2
GCC_VERSION="9.2.0"
GCC_DOWNLOAD_URL=https://ftp.gnu.org/gnu/gcc/gcc-${GCC_VERSION}/gcc-${GCC_VERSION}.tar.gz
$COMMON_DIR/write_component_version.sh "GCC" ${GCC_VERSION}
$COMMON_DIR/download_and_verify.sh $GCC_DOWNLOAD_URL "a931a750d6feadacbeecb321d73925cd5ebb6dfa7eff0802984af3aef63759f4"
tar -xvf gcc-${GCC_VERSION}.tar.gz
cd gcc-${GCC_VERSION}
./configure --disable-multilib --prefix=/opt/gcc-${GCC_VERSION} && make -j$(nproc) && make install
cd ..

# create modulefile
cat << EOF >> ${MODULE_FILES_DIRECTORY}/gcc-${GCC_VERSION}
#%Module 1.0
#
#  GCC ${GCC_VERSION}
#
prepend-path    PATH            /opt/gcc-${GCC_VERSION}/bin
prepend-path    LD_LIBRARY_PATH /opt/gcc-${GCC_VERSION}/lib64
setenv          CC              /opt/gcc-${GCC_VERSION}/bin/gcc
setenv          GCC             /opt/gcc-${GCC_VERSION}/bin/gcc
EOF

# cleanup downloaded tarballs
rm -rf *.tar.gz *tar.bz2
