#!/bin/bash
set -ex

# Import the newest AlmaLinux 8 GPG key
rpm --import https://repo.almalinux.org/almalinux/RPM-GPG-KEY-AlmaLinux

# jq is needed to parse the component versions from the versions.json file
yum install -y jq
