#!/bin/bash
set -ex

INSTALL_PREFIX=/opt/amd
mkdir -p ${INSTALL_PREFIX}

AOCL_VERSION="4.0"
TARBALL="aocl-linux-aocc-${AOCL_VERSION}.tar.gz"
AOCL_DOWNLOAD_URL=https://azhpcstor.blob.core.windows.net/azhpc-images-store/${TARBALL}
$COMMON_DIR/download_and_verify.sh $AOCL_DOWNLOAD_URL "c8000a66aaa2a257252cbb307732b4e66758b72b08f43b3723f4eb5404ba28c8"
tar -xvf ${TARBALL}

pushd aocl-linux-aocc-${AOCL_VERSION}
./install.sh -t amd -l blis fftw libflame -i lp64
cp -r amd/${AOCL_VERSION}/* ${INSTALL_PREFIX}
popd

# Setup module files for AMD Libraries
MODULE_FILES_DIRECTORY=/usr/share/Modules/modulefiles/amd
mkdir -p ${MODULE_FILES_DIRECTORY}

# fftw
cat << EOF >> ${MODULE_FILES_DIRECTORY}/aocl-${AOCL_VERSION}
#%Module 1.0
#
#  AOCL
#
prepend-path    LD_LIBRARY_PATH   ${INSTALL_PREFIX}/lib
setenv          AMD_FFTW_INCLUDE  ${INSTALL_PREFIX}/include
EOF

# Create symlinks for modulefiles
ln -s ${MODULE_FILES_DIRECTORY}/aocl-${AOCL_VERSION} ${MODULE_FILES_DIRECTORY}/aocl
$COMMON_DIR/write_component_version.sh "AOCL" ${AOCL_VERSION}

# cleanup downloaded files
rm -rf *tar.gz
