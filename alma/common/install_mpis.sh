#!/bin/bash
set -ex

# Load gcc
gcc_version=$(jq -r '.gcc."'"$DISTRIBUTION"'".version' <<< $COMPONENT_VERSIONS)
gcc_home=$(spack location -i gcc@$gcc_version)
export PATH=$gcc_home/bin:$PATH
export LD_LIBRARY_PATH=$gcc_home/lib64:$LD_LIBRARY_PATH
set CC=$gcc_home/bin/gcc
set GCC=$gcc_home/bin/gcc

module_files_directory=/usr/share/Modules/modulefiles/mpi/
$COMMON_DIR/install_mpis.sh $module_files_directory

# exclude updates on certain packages
sed -i "$ s/$/ ucx*/" /etc/dnf/dnf.conf
sed -i "$ s/$/ openmpi perftest/" /etc/dnf/dnf.conf
