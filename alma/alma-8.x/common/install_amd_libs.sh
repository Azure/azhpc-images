#!/bin/bash
set -ex

INSTALL_PREFIX=/opt/amd
mkdir -p ${INSTALL_PREFIX}

# Set AOCL version
amd_metadata=$(jq -r '.amd."'"$DISTRIBUTION"'"' <<< $COMPONENT_VERSIONS)
AOCL_VERSION=$(jq -r '.aocl.version' <<< $amd_metadata)
AOCL_SHA256=$(jq -r '.aocl.sha256' <<< $amd_metadata)

TARBALL="aocl-linux-aocc-${AOCL_VERSION}.tar.gz"
BASE_AOCL_VERSION=${AOCL_VERSION:0:3}
DIRECTORY="aocl-${BASE_AOCL_VERSION//./-}"
AOCL_DOWNLOAD_URL=https://download.amd.com/developer/eula/aocl/${DIRECTORY}/${TARBALL}
$COMMON_DIR/download_and_verify.sh $AOCL_DOWNLOAD_URL $AOCL_SHA256
tar -xvf ${TARBALL}

pushd aocl-linux-aocc-${AOCL_VERSION}
./install.sh -t amd -l blis fftw libflame -i lp64
cp -r amd/${AOCL_VERSION}/aocc/* ${INSTALL_PREFIX}
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
