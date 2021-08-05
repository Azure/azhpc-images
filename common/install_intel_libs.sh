#!/bin/bash
set -ex

VERSION="2021.1.1.52"
MKL_DOWNLOAD_URL=https://registrationcenter-download.intel.com/akdlm/irc_nas/17402/l_onemkl_p_${VERSION}_offline.sh
$COMMON_DIR/write_component_version.sh "INTEL_oneMKL" $VERSION
$COMMON_DIR/download_and_verify.sh $MKL_DOWNLOAD_URL "818b6bd9a6c116f4578cda3151da0612ec9c3ce8b2c8a64730d625ce5b13cc0c"
sudo bash l_onemkl_p_${VERSION}_offline.sh -s -a -s --eula accept
