#!/bin/bash
set -ex

# Load gcc
GCC_VERSION=gcc-9.2.0
export PATH=/opt/${GCC_VERSION}/bin:$PATH
export LD_LIBRARY_PATH=/opt/${GCC_VERSION}/lib64:$LD_LIBRARY_PATH
set CC=/opt/${GCC_VERSION}/bin/gcc
set GCC=/opt/${GCC_VERSION}/bin/gcc


INSTALL_PREFIX=/opt

# Install HPC-x
hpcx_metadata=$(jq -r '.hpcx."'"$DISTRIBUTION"'"' <<< $COMPONENT_VERSIONS)
HPCX_VERSION=$(jq -r '.version' <<< $hpcx_metadata)
HPCX_SHA256=$(jq -r '.sha256' <<< $hpcx_metadata)
HPCX_DOWNLOAD_URL=$(jq -r '.url' <<< $hpcx_metadata)
TARBALL=$(basename $HPCX_DOWNLOAD_URL)
HPCX_FOLDER=$(basename $HPCX_DOWNLOAD_URL .tbz)

$COMMON_DIR/download_and_verify.sh $HPCX_DOWNLOAD_URL $HPCX_SHA256
tar -xvf ${TARBALL}
mv ${HPCX_FOLDER} ${INSTALL_PREFIX}
HPCX_PATH=${INSTALL_PREFIX}/${HPCX_FOLDER}
$COMMON_DIR/write_component_version.sh "HPCX" $HPCX_VERSION

# exclude ucx from updates
sed -i "$ s/$/ ucx*/" /etc/dnf/dnf.conf

# Setup module files for MPIs
mkdir -p /usr/share/Modules/modulefiles/mpi/

# HPC-X
cat << EOF >> /usr/share/Modules/modulefiles/mpi/hpcx-${HPCX_VERSION}
#%Module 1.0
#
#  HPCx ${HPCX_VERSION}
#
conflict        mpi
module load ${HPCX_PATH}/modulefiles/hpcx
EOF

# Create symlinks for modulefiles
ln -s /usr/share/Modules/modulefiles/mpi/hpcx-${HPCX_VERSION} /usr/share/Modules/modulefiles/mpi/hpcx

# Install platform independent MPIs
$ALMA_COMMON_DIR/install_mpis.sh ${GCC_VERSION} ${HPCX_PATH}

# cleanup downloaded tarball for HPC-x
rm -rf *.tbz 
