#!/bin/bash

AOCC_VERSION=4.0.0-1

# install dependency
wget https://download.amd.com/developer/eula/aocc-compiler/aocc-compiler-${AOCC_VERSION}.x86_64.rpm
dnf install -y ./aocc-compiler-${AOCC_VERSION}.x86_64.rpm

rm ./aocc-compiler-${AOCC_VERSION}.x86_64.rpm

$COMMON_DIR/write_component_version.sh "AOCC" ${AOCC_VERSION}
