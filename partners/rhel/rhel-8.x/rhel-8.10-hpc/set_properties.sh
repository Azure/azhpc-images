#!/bin/bash

export TOP_DIR=$(realpath ../../../../)
export COMMON_DIR=$(realpath ../../../../components)
export COMPONENT_DIR=$COMMON_DIR
export RHEL_COMMON_DIR=$(realpath ../../common)
export TEST_DIR=$(realpath ../../../../tests)
export UTILS_DIR=$(realpath ../../../../utils)
export DISTRIBUTION=$(. /etc/os-release;echo $ID$VERSION_ID)

# Component Versions
export COMPONENT_VERSIONS=$(jq -r . ../../versions.json)
export MODULE_FILES_DIRECTORY=/usr/share/Modules/modulefiles
