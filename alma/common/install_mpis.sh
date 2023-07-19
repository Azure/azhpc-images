#!/bin/bash
set -ex

module_files_directory=/usr/share/Modules/modulefiles/mpi
$COMMON_DIR/install_mpis.sh $module_files_directory

# exclude updates on certain packages
sed -i "$ s/$/ ucx*/" /etc/dnf/dnf.conf
sed -i "$ s/$/ openmpi perftest/" /etc/dnf/dnf.conf
