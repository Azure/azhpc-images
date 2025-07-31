#!/bin/bash
set -ex

source /etc/lsb-release

echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft-prod.gpg] https://packages.microsoft.com/repos/amlfs-${DISTRIB_CODENAME}/ ${DISTRIB_CODENAME} main" | sudo tee /etc/apt/sources.list.d/amlfs.list

# Enable these lines if the MS PMC repo was not already setup.
#curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg
#cp ./microsoft.gpg /etc/apt/trusted.gpg.d/
