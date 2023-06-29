#!/bin/bash
set -ex

# Set AOCC and AOCL versions
amd_metadata=$(jq -r '.amd."'"$DISTRIBUTION"'"' <<< $COMPONENT_VERSIONS)
aocc_version=$(jq -r '.aocc.version' <<< $amd_metadata)
aocl_version=$(jq -r '.aocl.version' <<< $amd_metadata)

# Install AOCC
spack add aocc@$aocc_version
spack add amd-aocl@$aocl_version
spack install

$COMMON_DIR/write_component_version.sh "aocc" $aocc_version
$COMMON_DIR/write_component_version.sh "aocl" $aocl_version

# Setup module files for AMD Libraries
module_files_directory=/usr/share/Modules/modulefiles
amd_module_directory=$module_files_directory/amd
mkdir -p $amd_module_directory

aocl_home=$(spack location -i amd-aocl@$aocl_version)

# fftw
cat << EOF >> $amd_module_directory/aocl-$aocl_version
#%Module 1.0
#
#  AOCL
#
prepend-path    LD_LIBRARY_PATH   $aocl_home/lib
setenv          AMD_FFTW_INCLUDE  $aocl_home/include
EOF

# Create symlinks for modulefiles
ln -s $amd_module_directory/aocl-$aocl_version $amd_module_directory/aocl
