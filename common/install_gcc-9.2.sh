#!/bin/bash
set -x

MODULE_FILES_DIRECTORY=$1

# Install gcc 9.2
wget ftp://gcc.gnu.org/pub/gcc/infrastructure/gmp-6.1.0.tar.bz2
tar -xvf gmp-6.1.0.tar.bz2
cd ./gmp-6.1.0
./configure && make -j$(nproc) &&  make install
cd ..

wget ftp://gcc.gnu.org/pub/gcc/infrastructure/mpfr-3.1.4.tar.bz2
tar -xvf mpfr-3.1.4.tar.bz2
cd mpfr-3.1.4
./configure && make -j$(nproc) &&  make install
cd ..

wget ftp://gcc.gnu.org/pub/gcc/infrastructure/mpc-1.0.3.tar.gz
tar -xvf mpc-1.0.3.tar.gz
cd mpc-1.0.3
./configure && make -j$(nproc) &&  make install
cd ..

# install gcc 9.2
wget https://ftp.gnu.org/gnu/gcc/gcc-9.2.0/gcc-9.2.0.tar.gz
tar -xvf gcc-9.2.0.tar.gz
cd gcc-9.2.0
./configure --disable-multilib --prefix=/opt/gcc-9.2.0 && make -j$(nproc) && make install
cd ..

# create modulefile
cat << EOF >> ${MODULE_FILES_DIRECTORY}/gcc-9.2.0
#%Module 1.0
#
#  GCC 9.2.0
#
prepend-path    PATH            /opt/gcc-9.2.0/bin
prepend-path    LD_LIBRARY_PATH /opt/gcc-9.2.0/lib64
setenv          CC              /opt/gcc-9.2.0/bin/gcc
setenv          GCC             /opt/gcc-9.2.0/bin/gcc
EOF

