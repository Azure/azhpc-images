#!/bin/bash
set -ex

# Don't allow the kernel to be updated
apt-mark hold linux-azure

# upgrade pre-installed components
apt update
apt upgrade -y

# jq is needed to parse the component versions from the versions.json file
apt install -y jq
