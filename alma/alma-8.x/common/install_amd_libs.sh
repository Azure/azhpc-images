#!/bin/bash
set -ex

INSTALL_PREFIX=/opt/amd
mkdir -p ${INSTALL_PREFIX}

AOCL_VERSION="3.1.0"
TARBALL="aocl-linux-aocc-${AOCL_VERSION}.tar.gz"
AOCL_DOWNLOAD_URL=https://azhpcstor.blob.core.windows.net/azhpc-images-store/${TARBALL}
$COMMON_DIR/download_and_verify.sh $AOCL_DOWNLOAD_URL "1881ea77e3addff90a064ff300f15a611a0f1208ceedea39aba328de7ed2c8e7"
tar -xvf ${TARBALL}

cd aocl-linux-aocc-${AOCL_VERSION}
./install.sh -t amd -l blis fftw libflame -i lp64
cp -r amd/3.1.0/* ${INSTALL_PREFIX}
cd .. && rm -rf aocl-linux-aocc-${AOCL_VERSION}

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
$COMMON_DIR/write_component_version.sh "AOCL" ${AOCL_VERSION}

# cleanup downloaded files
rm -rf *tar.gz
