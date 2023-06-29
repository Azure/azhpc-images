#!/bin/bash
set -ex

# Load gcc
set CC=/usr/bin/gcc
set GCC=/usr/bin/gcc

module_files_directory=/usr/share/modules/modulefiles/mpi
$COMMON_DIR/install_mpis.sh $module_files_directory
