#!/bin/bash

export TOP_DIR=../../..
export COMMON_DIR=../../../common
export UBUNTU_COMMON_DIR=../../common
export TEST_DIR=../../../tests
export DISTRIBUTION=$(. /etc/os-release;echo $ID$VERSION_ID)

# Environments
export HPC_ENV=/opt/azurehpc
export MODULE_FILES_DIRECTORY=/usr/share/modules/modulefiles

# Component Versions
export COMPONENT_VERSIONS=$(jq -r . $TOP_DIR/requirements.json)
