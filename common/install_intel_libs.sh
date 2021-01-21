#!/bin/bash
set -ex

# Install MKL
# MKL_DOWNLOAD_URL=http://registrationcenter-download.intel.com/akdlm/irc_nas/tec/15816/l_mkl_2019.5.281.tgz
# $COMMON_DIR/download_and_verify.sh $MKL_DOWNLOAD_URL "9995ea4469b05360d509c9705e9309dc983c0a10edc2ae3a5384bc837326737e"
# tar -xvf l_mkl_2019.5.281.tgz
# cd l_mkl_2019.5.281
# sed -i -e 's/ACCEPT_EULA=decline/ACCEPT_EULA=accept/g' silent.cfg
# ./install.sh --silent ./silent.cfg


MKL_DOWNLOAD_URL=https://registrationcenter-download.intel.com/akdlm/irc_nas/17402/l_onemkl_p_2021.1.1.52_offline.sh
$COMMON_DIR/download_and_verify.sh $MKL_DOWNLOAD_URL "818b6bd9a6c116f4578cda3151da0612ec9c3ce8b2c8a64730d625ce5b13cc0c"
sudo bash l_onemkl_p_2021.1.1.52_offline.sh -s -a -s --eula accept

