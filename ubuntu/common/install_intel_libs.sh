#!/bin/bash
set -ex


# Intel® oneAPI Math Kernel Library
VERSION="2023.0.0.25398"
ONE_MKL_DOWNLOAD_URL=https://registrationcenter-download.intel.com/akdlm/irc_nas/19138/l_onemkl_p_${VERSION}_offline.sh
$COMMON_DIR/write_component_version.sh "INTEL_ONE_MKL" $VERSION
$COMMON_DIR/download_and_verify.sh ${ONE_MKL_DOWNLOAD_URL} "0d61188e91a57bdb575782eb47a05ae99ea8eebefee6b2dfe20c6708e16e9927"
sh ./l_onemkl_p_${VERSION}_offline.sh -s -a -s --eula accept
