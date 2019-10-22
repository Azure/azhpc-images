#!/bin/bash
set -ex

# Load gcc
GCC_VERSION=gcc-9.2.0
export PATH=/opt/${GCC_VERSION}/bin:$PATH
export LD_LIBRARY_PATH=/opt/${GCC_VERSION}/lib64:$LD_LIBRARY_PATH
set CC=/opt/${GCC_VERSION}/bin/gcc
set GCC=/opt/${GCC_VERSION}/bin/gcc

yum install -y texinfo
INSTALL_PREFIX=/opt/amd
mkdir -p ${INSTALL_PREFIX}

# AMD FFTW
wget https://github.com/amd/amd-fftw/releases/download/2.0/aocl-fftw-centos-2.0.tar.gz
tar -xvf aocl-fftw-centos-2.0.tar.gz
cp -r amd-fftw ${INSTALL_PREFIX}/fftw


# AMD libflame
wget https://github.com/amd/libflame/releases/download/2.0/aocl-libflame-centos-2.0.tar.gz
tar -xvf aocl-libflame-centos-2.0.tar.gz
cp -r amd-libflame ${INSTALL_PREFIX}/libflame


# AMD blis 
wget https://github.com/amd/blis/releases/download/2.0/aocl-blis-centos-2.0.tar.gz
tar -xvf aocl-blis-centos-2.0.tar.gz
cp -r amd-blis ${INSTALL_PREFIX}/blis


# AMD blis-mt
wget https://github.com/amd/blis/releases/download/2.0/aocl-blis-mt-centos-2.0.tar.gz
tar -xvf aocl-blis-mt-centos-2.0.tar.gz
cp -r amd-blis-mt ${INSTALL_PREFIX}/blis-mt

