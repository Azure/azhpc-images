#!/bin/bash
set -ex

# upgrade pre-installed components
apt update

# install LTS kernel
apt install -y linux-azure-lts-22.04

# jq is needed to parse the component versions from the requirements.json file
apt install -y jq
