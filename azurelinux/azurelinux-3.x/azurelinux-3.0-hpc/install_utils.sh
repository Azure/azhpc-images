#!/bin/bash
set -ex

# Setup microsoft packages repository for moby
# Download the repository configuration package
# curl https://packages.microsoft.com/config/rhel/8/prod.repo > ./microsoft-prod.repo
# Copy the generated list to the sources.list.d directory
# cp ./microsoft-prod.repo /etc/yum.repos.d/

tdnf repolist

echo "Printing variable in install_utils"
echo ${AZURE_LINUX_COMMON_DIR}
pwd

$AZURE_LINUX_COMMON_DIR/install_utils.sh
