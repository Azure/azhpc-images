#!/bin/bash
set -ex


# Intel® oneAPI Math Kernel Library
VERSION="2022.1.0.223"
ONE_MKL_DOWNLOAD_URL=https://registrationcenter-download.intel.com/akdlm/irc_nas/18721/l_onemkl_p_${VERSION}_offline.sh
$COMMON_DIR/write_component_version.sh "INTEL_ONE_MKL" $VERSION
$COMMON_DIR/download_and_verify.sh ${ONE_MKL_DOWNLOAD_URL} "4b325a3c4c56e52f4ce6c8fbb55d7684adc16425000afc860464c0f29ea4563e"
sh ./l_onemkl_p_${VERSION}_offline.sh -s -a -s --eula accept
