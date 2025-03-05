#!/bin/bash
set -ex

source ${COMMON_DIR}/utilities.sh

INSTALL_PREFIX=/opt/amd
mkdir -p ${INSTALL_PREFIX}

# Set AOCL version
amd_metadata=$(get_component_config "amd")
AOCL_VERSION=$(jq -r '.aocl.version' <<< $amd_metadata)
AOCL_SHA256=$(jq -r '.aocl.sha256' <<< $amd_metadata)

AOCL_TARBALL="aocl-linux-aocc-${AOCL_VERSION}.tar.gz"
AOCL_FOLDER_VERSION=$(echo $AOCL_VERSION | cut -d'.' -f1-2 --output-delimiter='-')
AOCL_DOWNLOAD_URL=https://download.amd.com/developer/eula/aocl/aocl-${AOCL_FOLDER_VERSION}/${AOCL_TARBALL}
AOCL_FOLDER=$(basename $AOCL_TARBALL .tar.gz)

$COMMON_DIR/download_and_verify.sh $AOCL_DOWNLOAD_URL $AOCL_SHA256
tar -xvf ${AOCL_TARBALL}

pushd ${AOCL_FOLDER}
./install.sh -t amd -l blis fftw libflame -i lp64
cp -r amd/${AOCL_VERSION}/aocc/* ${INSTALL_PREFIX}
popd

# Setup module files for AMD Libraries
AMD_MODULE_FILES_DIRECTORY=${MODULE_FILES_DIRECTORY}/amd
mkdir -p ${AMD_MODULE_FILES_DIRECTORY}

# fftw
cat << EOF >> ${AMD_MODULE_FILES_DIRECTORY}/aocl-${AOCL_VERSION}
#%Module 1.0
#
#  AOCL
#
prepend-path    LD_LIBRARY_PATH   ${INSTALL_PREFIX}/lib
setenv          AMD_FFTW_INCLUDE  ${INSTALL_PREFIX}/include
EOF

# Create symlinks for modulefiles
ln -s ${AMD_MODULE_FILES_DIRECTORY}/aocl-${AOCL_VERSION} ${AMD_MODULE_FILES_DIRECTORY}/aocl
$COMMON_DIR/write_component_version.sh "AOCL" ${AOCL_VERSION}

# Install AMD Optimizing C/C++ and Fortran Compilers
AOCC_VERSION=$(jq -r '.aocc.version' <<< $amd_metadata)
AOCC_SHA256=$(jq -r '.aocc.sha256' <<< $amd_metadata)
AOCC_TARBALL="aocc-compiler-${AOCC_VERSION}.tar"
AOCC_FOLDER_VERSION=$(echo $AOCC_VERSION | cut -d'.' -f1-2 --output-delimiter='-')
AOCC_DOWNLOAD_URL=https://download.amd.com/developer/eula/aocc/aocc-${AOCC_FOLDER_VERSION}/${AOCC_TARBALL}
AOCC_FOLDER=$(basename $AOCC_TARBALL .tar)

$COMMON_DIR/download_and_verify.sh $AOCC_DOWNLOAD_URL $AOCC_SHA256
tar -xvf ${AOCC_TARBALL}

pushd ${AOCC_FOLDER}
./install.sh
popd
cp -r ${AOCC_FOLDER} ${INSTALL_PREFIX}

$COMMON_DIR/write_component_version.sh "AOCC" ${AOCC_VERSION}

# cleanup downloaded files
rm -rf *.tar *.tar.gz
rm -rf ${AOCL_FOLDER}
rm -rf ${AOCC_FOLDER}
