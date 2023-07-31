#!/bin/bash

# Directories
export TOP_DIR=../../..
export COMMON_DIR=../../../common
export ALMA_COMMON_DIR=../../common
export TEST_DIR=../../../tests
export DISTRIBUTION=$(. /etc/os-release;echo $ID$VERSION_ID)

# Environments
export HPC_ENV=/opt/azurehpc

# Component Versions
export COMPONENT_VERSIONS=$(jq -r . $TOP_DIR/requirements.json)

# Kernel
export KERNEL=$(rpm -q kernel | sed 's/kernel\-//g')
