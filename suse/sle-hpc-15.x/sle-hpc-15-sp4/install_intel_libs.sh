#!/bin/bash
set -ex

# Intel® oneAPI Math Kernel Library

# Intel provides oneapi RPM packages for SUSE
# and the repository is set up in install_utils.sh
# so we can simply install the needed package
zypper install -y -l intel-oneapi-mkl

#VERSION="2022.1.0.223"
VERSION=$(rpm -q  --qf="%{VERSION}" intel-oneapi-mkl)
$COMMON_DIR/write_component_version.sh "INTEL_ONE_MKL" $VERSION
