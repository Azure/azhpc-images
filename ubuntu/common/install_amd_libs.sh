#!/bin/bash

AOCC_VERSION=4.0.0_1

# install dependency
wget https://download.amd.com/developer/eula/aocc-compiler/aocc-compiler-${AOCC_VERSION}_amd64.deb
apt install -y ./aocc-compiler-${AOCC_VERSION}_amd64.deb

rm aocc-compiler-${AOCC_VERSION}_amd64.deb 

$COMMON_DIR/write_component_version.sh "AOCC" ${AOCC_VERSION}
