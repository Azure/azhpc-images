#!/bin/bash
set -ex

# Install pre-reqs and development tools

zypper install --no-confirm \
    bzip2

# Install azcopy tool 
# To copy blobs or files to or from a storage account.
wget https://azcopyvnextrelease.blob.core.windows.net/release20210920/azcopy_linux_se_amd64_10.12.2.tar.gz
tar -xvf azcopy_linux_se_amd64_10.12.2.tar.gz

# copy the azcopy to the bin path
pushd azcopy_linux_se_amd64_10.12.2
cp azcopy /usr/bin/
popd

# Allow execute permissions
chmod +x /usr/bin/azcopy
