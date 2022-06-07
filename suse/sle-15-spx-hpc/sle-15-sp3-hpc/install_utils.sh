#!/bin/bash
set -ex

zypper refresh

# update packages
# lock current kernel
# TODO consider introducing reboot into workflow
zypper addlock kernel-${KERNEL} kernel-source${KERNEL_FLAVOR} kernel-syms${KERNEL_FLAVOR}
zypper update --no-confirm
zypper removelock kernel-${KERNEL} kernel-source${KERNEL_FLAVOR} kernel-syms${KERNEL_FLAVOR}

# Install pre-reqs and development tools
zypper install --no-confirm \
    bzip2

# Install azcopy tool 
# To copy blobs or files to or from a storage account.
AZCOPY_ARCHIVE=azcopy_linux_se_amd64_10.12.2.tar.gz

if ! [[ -f $AZCOPY_ARCHIVE ]]; then
    wget https://azcopyvnextrelease.blob.core.windows.net/release20210920/${AZCOPY_ARCHIVE}
    tar -xvf ${AZCOPY_ARCHIVE}
fi

# copy the azcopy to the bin path
pushd azcopy_linux_se_amd64_10.12.2
cp azcopy /usr/bin/
popd

# Allow execute permissions
chmod +x /usr/bin/azcopy
