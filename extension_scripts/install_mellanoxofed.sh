#!/bin/bash

distro=`./../common/extract_distro.sh`
if [ $? -eq 0 ]
then
    echo "Detected distro: ${distro}"
else
    echo "*** Error - invalid distro!"
    exit -1
fi

if [[ $distro == "CentOS Linux 7.6.1810" ]]
then
    pushd "../centos/centos-7.x/centos-7.6-hpc"
elif [[ $distro == "CentOS Linux 7.7.1908" ]]
then
    pushd "../centos/centos-7.x/centos-7.7-hpc"
elif [[ $distro == "CentOS Linux 8.1.1911" ]]
then
    pushd "../centos/centos-8.x/centos-8.1-hpc"
elif [[ $distro == "Ubuntu 18.04.4" ]]
then
    pushd "../ubuntu/ubuntu-18.04-hpc"
else
    echo "*** Error - unsupported distro!"
    exit -1
fi

./install_mellanoxofed.sh
popd

exit 0
