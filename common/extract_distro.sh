#!/bin/bash

# Find CentOS distro
find_centos_distro() {
    echo `cat /etc/redhat-release | awk '{print $4}'`
}

# Find Ubuntu distro
find_ubuntu_distro() {
    echo `cat /etc/os-release | awk 'match($0, /^PRETTY_NAME="(.*)"/, result) { print result[1] }' | awk '{print $2}'`
}

# Find distro
os=`cat /etc/os-release | awk 'match($0, /^NAME="(.*)"/, result) { print result[1] }'`
if [[ $os == "CentOS Linux" ]]
then
    centos_distro=`find_centos_distro`
    echo "${os} ${centos_distro}"
elif [[ $os == "Ubuntu" ]]
then
    ubuntu_distro=`find_ubuntu_distro`
    echo "${os} ${ubuntu_distro}"
else
    echo "*** Error - invalid distro!"
    exit -1
fi

exit 0
