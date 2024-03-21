#!/bin/bash
set -ex

source /etc/bashrc

# Set AOCC and AOCL versions
amd_metadata=$(jq -r '.amd."'"$DISTRIBUTION"'"' <<< $COMPONENT_VERSIONS)
aocc_version=$(jq -r '.aocc.version' <<< $amd_metadata)

# Create an environment for amd related packages
spack env create -d /opt/amd
spack env activate /opt/amd

# Install AOCC
spack add aocc@$aocc_version +license-agreed
spack concretize -f
spack install

$COMMON_DIR/write_component_version.sh "aocc" $aocc_version

# Clear the ununsed packages
spack gc -y
# return to the old environment
# deactivate existing environment
# despacktivate
spack env activate -d $HPC_ENV
