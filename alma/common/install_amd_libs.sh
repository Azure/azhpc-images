#!/bin/bash
set -ex

source /etc/profile

# Set AOCC and AOCL versions
amd_metadata=$(jq -r '.amd."'"$DISTRIBUTION"'"' <<< $COMPONENT_VERSIONS)
aocc_version=$(jq -r '.aocc.version' <<< $amd_metadata)
aocl_version=$(jq -r '.aocl.version' <<< $amd_metadata)

# Set the GCC version
gcc_version=$(jq -r '.gcc."'"$DISTRIBUTION"'".version' <<< $COMPONENT_VERSIONS)
spack env activate /opt/gcc-$gcc_version
gcc_home=$(spack location -i gcc@$gcc_version)

# Create an environment for amd related packages
spack env create -d /opt/amd
spack env activate /opt/amd

# Add GCC to the list of compiler in the amd env
spack compiler add $gcc_home

# Install AOCC
spack add aocc@$aocc_version +license-agreed
spack add amd-aocl@$aocl_version %gcc@$gcc_version
spack concretize -f
spack install

$COMMON_DIR/write_component_version.sh "aocc" $aocc_version
$COMMON_DIR/write_component_version.sh "aocl" $aocl_version

# Setup module files for AMD Libraries
amd_module_directory=$MODULE_FILES_DIRECTORY/amd
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

spack gc -y
# return to the old environment
# deactivate existing environment
# despacktivate
spack env activate -d $HPC_ENV

# Create symlinks for modulefiles
ln -s $amd_module_directory/aocl-$aocl_version $amd_module_directory/aocl
