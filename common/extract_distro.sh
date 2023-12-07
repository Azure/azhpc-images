#!/bin/bash

# Find Ubuntu distro
find_ubuntu_distro() {
    echo `cat /etc/os-release | awk 'match($0, /^PRETTY_NAME="(.*)"/, result) { print result[1] }' | awk '{print $2}'`
}

# Find distro
os=`cat /etc/os-release | awk 'match($0, /^NAME="(.*)"/, result) { print result[1] }'`
if [[ $os == "Ubuntu" ]]
then
    ubuntu_distro=`find_ubuntu_distro`
    echo "${os} ${ubuntu_distro}"
else
    echo "*** Error - invalid distro!"
    exit -1
fi

exit 0
