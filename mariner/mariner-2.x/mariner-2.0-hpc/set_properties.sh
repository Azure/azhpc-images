#!/bin/bash

# Directories
export TOP_DIR=../../..
export COMMON_DIR=../../../common
export MARINER_COMMON_DIR=../../common
export TEST_DIR=../../../tests
export DISTRIBUTION=$(. /etc/os-release;echo $ID$VERSION_ID)

# Environments
export HPC_ENV=/opt/azurehpc
export MODULE_FILES_DIRECTORY=/usr/share/Modules/modulefiles

# Component Versions
export COMPONENT_VERSIONS=$(jq -r . $TOP_DIR/requirements.json)

# Kernel
export KERNEL=$(rpm -q kernel | sed 's/kernel\-//g')

$COMMON_DIR/write_component_version.sh "distribution" $DISTRIBUTION