#!/bin/bash
set -ex

# Set Intel® oneAPI Math Kernel Library version
intel_one_mkl_version=$(jq -r '.intel_one_mkl."'"$DISTRIBUTION"'".version' <<< $COMPONENT_VERSIONS)

spack add intel-oneapi-mkl@$intel_one_mkl_version
# If there is a space crunch use spack gc (this performs garbage collection)
# spack gc -y
spack concretize -f
spack install
$COMMON_DIR/write_component_version.sh "intel_one_mkl" $intel_one_mkl_version
