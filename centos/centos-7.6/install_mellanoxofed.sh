#!/bin/bash
set -ex

wget https://www.mellanox.com/downloads/ofed/MLNX_OFED-4.7-1.0.0.1/MLNX_OFED_LINUX-4.7-1.0.0.1-rhel7.6-x86_64.tgz
tar zxvf MLNX_OFED_LINUX-4.7-1.0.0.1-rhel7.6-x86_64.tgz
./MLNX_OFED_LINUX-4.7-1.0.0.1-rhel7.6-x86_64/mlnxofedinstall --force

