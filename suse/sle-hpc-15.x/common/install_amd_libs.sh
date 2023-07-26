#!/bin/bash
set -ex

## AMD provides RPM packages, so in theory no need to use tarballs,
## but there is no way to get around the licence section at the website
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

TARBALL=$(basename $AOCL_DOWNLOAD_URL)

# TODO: this seems a workaround to accept the licence prior download
# should be fixed in readme and made be more general e.g. prior download of the rpm and not the tarball
$COMMON_DIR/download_and_verify.sh $AOCL_DOWNLOAD_URL $AOCL_CHKSUM
tar -xvf ${TARBALL}

cd aocl-linux-aocc-${AOCL_VERSION}
./install.sh -t amd -l blis fftw libflame -i lp64
cp -r amd/${AOCL_VERSION}/* ${INSTALL_PREFIX}
cd .. && rm -rf aocl-linux-aocc-${AOCL_VERSION} ${TARBALL}

$COMMON_DIR/write_component_version.sh "AOCL" ${AOCL_VERSION}

# Setup module files for AMD Libraries
# SUSE HPC uses lmod by default
mkdir -p ${MODULE_FILES_DIRECTORY}/amd/

cat << EOF >> ${MODULE_FILES_DIRECTORY}/amd/aocl-${AOCL_VERSION}

#%Module 1.0
#
#  AOCL
#
prepend-path    LD_LIBRARY_PATH   ${INSTALL_PREFIX}/lib
setenv          AMD_FFTW_INCLUDE  ${INSTALL_PREFIX}/include
EOF

# Create symlinks for modulefiles
ln -sf $(readlink --canonicalize ${MODULE_FILES_DIRECTORY}/amd/aocl-${AOCL_VERSION}) ${MODULE_FILES_DIRECTORY}/amd/aocl

