#!/bin/bash
set -ex

case ${DISTRIBUTION} in
    "rhel8.6") INTEL_MKL_VERSION="2022.1.0.223";
        RELEASE_VERSION="18721";
        CHECKSUM="4b325a3c4c56e52f4ce6c8fbb55d7684adc16425000afc860464c0f29ea4563e";
        IDENTIFIER="irc_nas";
        ;;
    "rhel8.7") INTEL_MKL_VERSION="2023.1.0.46342";
        RELEASE_VERSION="cd17b7fe-500e-4305-a89b-bd5b42bfd9f8";
        CHECKSUM="cc28c94cab23c185520b93c5a04f3979d8da6b4c90cee8c0681dd89819d76167";
        IDENTIFIER="IRC_NAS";
        ;;
    *) ;;
esac

# Intel® oneAPI Math Kernel Library
ONE_MKL_DOWNLOAD_URL=https://registrationcenter-download.intel.com/akdlm/${IDENTIFIER}/${RELEASE_VERSION}/l_onemkl_p_${INTEL_MKL_VERSION}_offline.sh
$COMMON_DIR/write_component_version.sh "INTEL_ONE_MKL" ${INTEL_MKL_VERSION}
$COMMON_DIR/download_and_verify.sh ${ONE_MKL_DOWNLOAD_URL} ${CHECKSUM}
sh ./l_onemkl_p_${INTEL_MKL_VERSION}_offline.sh -s -a -s --eula accept
