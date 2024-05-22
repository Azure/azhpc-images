#!/bin/bash

export TOP_DIR=../../..
export COMMON_DIR=../../../common
export ALMA_COMMON_DIR=../../common
export TEST_DIR=../../../tests
export DISTRIBUTION=$(. /etc/os-release;echo $ID$VERSION_ID)

# Component Versions
export COMPONENT_VERSIONS=$(jq -r . $TOP_DIR/requirements.json)
