#!/bin/bash
set -ex

# Intel® oneAPI Math Kernel Library

# Intel provides oneapi RPM packages for SUSE
# and the repository is set up in install_utils.sh
# so we can simply install the needed package

# workaround for wrong multi-version repos of intel.
# instead of use the version for a package search and install
# we need to provide a fixed name including the version
# so instead of
# zypper install -y -l intel-oneapi-mkl = $INTEL_ONE_MKL_VERSION
# we forced to use
zypper --non-interactive install -y -l intel-oneapi-mkl-$INTEL_ONE_MKL_VERSION

$COMMON_DIR/write_component_version.sh "INTEL_ONE_MKL" $INTEL_ONE_MKL_VERSION
