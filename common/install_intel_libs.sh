#!/bin/bash
set -ex

# Install MKL
wget http://registrationcenter-download.intel.com/akdlm/irc_nas/tec/15816/l_mkl_2019.5.281.tgz
tar -xvf l_mkl_2019.5.281.tgz
cd l_mkl_2019.5.281
sed -i -e 's/ACCEPT_EULA=decline/ACCEPT_EULA=accept/g' silent.cfg
./install.sh --silent ./silent.cfg

