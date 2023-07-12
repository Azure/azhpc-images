#!/bin/bash
set -ex

module_files_directory=/usr/share/Modules/modulefiles
mkdir -p ${module_files_directory}

# Set the GCC version
gcc_version=$(jq -r '.gcc."'"$DISTRIBUTION"'".version' <<< $COMPONENT_VERSIONS)

spack add gcc@$gcc_version
spack install

gcc_home=$(spack location -i gcc@$gcc_version)

# create modulefile
cat << EOF >> ${module_files_directory}/gcc-$gcc_version
#%Module 1.0
#
#  GCC $gcc_version
#
prepend-path    PATH            $gcc_home/bin
prepend-path    LD_LIBRARY_PATH $gcc_home/lib64
setenv          CC              $gcc_home/bin/gcc
setenv          GCC             $gcc_home/bin/gcc
EOF

# set gcc version as the default compiler version
spack compiler find # Adds 9.2.0 to the list
