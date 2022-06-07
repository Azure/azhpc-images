#!/bin/bash

export KERNEL=$(uname -r | awk -F- '{print $(NF)}')
export KERNEL_VERSION_RELEASE=$(rpm -qa kernel-${KERNEL} --queryformat "%{VERSION}-%{RELEASE}")

if [[ ${KERNEL} == "default" ]]; then
    export KERNEL_FLAVOR=""
else
    export KERNEL_FLAVOR="-${KERNEL}"
fi

export MOFED_VERSION=5.6-2.0.9.0
