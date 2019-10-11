#!/bin/bash
set -ex

wget http://content.mellanox.com/ofed/MLNX_OFED-4.7-1.0.0.1/MLNX_OFED_LINUX-4.7-1.0.0.1-rhel7.7-x86_64.tgz
tar zxvf MLNX_OFED_LINUX-4.7-1.0.0.1-rhel7.7-x86_64.tgz
./MLNX_OFED_LINUX-4.7-1.0.0.1-rhel7.7-x86_64/mlnxofedinstall --force

