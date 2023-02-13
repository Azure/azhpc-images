#!/bin/bash
set -ex

# PARAMETER
VERSION=$1

# Intel® oneAPI Math Kernel Library
case ${VERSION} in
    1804) INTEL_MKL_VERSION="2022.1.0.223";
        CHECKSUM="4b325a3c4c56e52f4ce6c8fbb55d7684adc16425000afc860464c0f29ea4563e";; 
    2004) INTEL_MKL_VERSION="2023.0.0.25398";
        CHECKSUM="0d61188e91a57bdb575782eb47a05ae99ea8eebefee6b2dfe20c6708e16e9927";;
    *) ;;
esac

ONE_MKL_DOWNLOAD_URL=https://registrationcenter-download.intel.com/akdlm/irc_nas/18721/l_onemkl_p_${INTEL_MKL_VERSION}_offline.sh
$COMMON_DIR/write_component_version.sh "INTEL_ONE_MKL" ${INTEL_MKL_VERSION}
$COMMON_DIR/download_and_verify.sh ${ONE_MKL_DOWNLOAD_URL} ${CHECKSUM}
sh ./l_onemkl_p_${INTEL_MKL_VERSION}_offline.sh -s -a -s --eula accept
