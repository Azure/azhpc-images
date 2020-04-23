#!/bin/bash

distro=`./../common/extract_distro.sh`
if [ $? -eq 0 ]
then
    echo "Detected distro: ${distro}"
else
    echo "*** Error - invalid distro!"
    exit -1
fi

if [[ $distro == "Ubuntu 18.04.4" ]]
then
    pushd "../ubuntu/ubuntu-18.04-hpc"
else
    echo "*** Error - unsupported distro!"
    exit -1
fi

./install_nvidiagpudriver.sh
popd

exit 0
