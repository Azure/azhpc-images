#!/bin/bash
set -ex

case ${DISTRIBUTION} in
    "almalinux8.6") INTEL_MKL_VERSION="2022.1.0.223";
        RELEASE_VERSION="18721";
        CHECKSUM="4b325a3c4c56e52f4ce6c8fbb55d7684adc16425000afc860464c0f29ea4563e";
        IDENTIFIER="irc_nas";
        ;;
    "almalinux8.7") INTEL_MKL_VERSION="2023.2.0.49497";
        RELEASE_VERSION="adb8a02c-4ee7-4882-97d6-a524150da358";
        CHECKSUM="4a0d93da85a94d92e0ad35dc0fc3b3ab7f040bd55ad374c4d5ec81a57a2b872b";
        IDENTIFIER="IRC_NAS";
        ;;
    *) ;;
esac

# Intel® oneAPI Math Kernel Library
ONE_MKL_DOWNLOAD_URL=https://registrationcenter-download.intel.com/akdlm/${IDENTIFIER}/${RELEASE_VERSION}/l_onemkl_p_${INTEL_MKL_VERSION}_offline.sh
$COMMON_DIR/write_component_version.sh "INTEL_ONE_MKL" ${INTEL_MKL_VERSION}
$COMMON_DIR/download_and_verify.sh ${ONE_MKL_DOWNLOAD_URL} ${CHECKSUM}
sh ./l_onemkl_p_${INTEL_MKL_VERSION}_offline.sh -s -a -s --eula accept
