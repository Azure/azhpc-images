#!/bin/bash
set -ex

# install pre-requisites
./install_prerequisites.sh

# set properties
source ./set_properties.sh

# install spack
$ALMA_COMMON_DIR/install_spack.sh
# Activate the environment/ container
source /etc/profile
export PATH="/sbin:/bin:/usr/sbin:/usr/bin:$PATH"

# install compilers
./install_gcc.sh

# install AMD tuned libraries
# $ALMA_COMMON_DIR/install_amd_libs.sh

# install utils
./install_utils.sh

