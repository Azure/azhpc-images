#!/bin/bash
set -ex
#
## changelog
#
# 20220809 - ps - adopt suse lmod
#                 hints to use RPM or spack instead of tarball
#                 hint to actual version
#

## AMD provides RPM packages, so no need to use tarballs
## https://developer.amd.com/amd-aocl/#downloads
## there are two options, gcc 11.1 or AOCC3.2
## aocl-linux-aocc- 3.1.0-1.x86_64.rpm
## aocl-linux-gcc-3.1.0-1.x86_64.rpm
## do be able to download you need to agree to licence
#
# Additionally, AMD provides the Spack (https://spack.io/) recipes for optimally installing BLIS,
# libFLAME, ScaLAPACK, LibM, FFTW, and Sparse libraries

INSTALL_PREFIX=/opt/amd
mkdir -p ${INSTALL_PREFIX}

AOCL_VERSION="3.1.0"
# actual AOCL_VERSION="3.2.0"

TARBALL="aocl-linux-aocc-${AOCL_VERSION}.tar.gz"

# TODO: this seems a workaround to accept the licence prior download
# should be fixed in readme and made be more general e.g. prior download of the rpm and not the tarball
AOCL_DOWNLOAD_URL=https://azhpcstor.blob.core.windows.net/azhpc-images-store/${TARBALL}
$COMMON_DIR/download_and_verify.sh $AOCL_DOWNLOAD_URL "1881ea77e3addff90a064ff300f15a611a0f1208ceedea39aba328de7ed2c8e7"
tar -xvf ${TARBALL}

cd aocl-linux-aocc-${AOCL_VERSION}
./install.sh -t amd -l blis fftw libflame -i lp64
cp -r amd/${AOCL_VERSION}/* ${INSTALL_PREFIX}
cd .. && rm -rf aocl-linux-aocc-${AOCL_VERSION}

$COMMON_DIR/write_component_version.sh "AOCL" ${AOCL_VERSION}

# Setup module files for AMD Libraries
# SUSE HPC uses lmod by default
mkdir -p /usr/share/lmod/modulefiles/amd/

# fftw
cat << EOF >> /usr/share/lmod/modulefiles/amd/aocl-${AOCL_VERSION}
#%Module 1.0
#
#  AOCL
#
prepend-path    LD_LIBRARY_PATH   ${INSTALL_PREFIX}/lib
setenv          AMD_FFTW_INCLUDE  ${INSTALL_PREFIX}/include
EOF

# Create symlinks for modulefiles
ln -s /usr/share/lmod/modulefiles/amd/aocl-${AOCL_VERSION} /usr/share/lmod/modulefiles/amd/aocl
$COMMON_DIR/write_component_version.sh "AOCL" ${AOCL_VERSION}
