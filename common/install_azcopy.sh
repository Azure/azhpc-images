#!/bin/bash
set -ex

# To copy blobs or files to or from a storage account
azcopy_metadata=$(jq -r '.azcopy."'"$DISTRIBUTION"'"' <<< $COMPONENT_VERSIONS)
azcopy_version=$(jq -r '.version' <<< $azcopy_metadata)
azcopy_release=$(jq -r '.release' <<< $azcopy_metadata)
azcopy_sha256=$(jq -r '.sha256' <<< $azcopy_metadata)
TARBALL="azcopy_linux_amd64_$azcopy_version.tar.gz"
AZCOPY_DOWNLOAD_URL="https://azcopyvnext.azureedge.net/$azcopy_release/$TARBALL"
wget ${AZCOPY_DOWNLOAD_URL}
tar -xvf ${TARBALL}

# copy the azcopy to the bin path
pushd azcopy_linux_amd64_${azcopy_version}
cp azcopy /usr/bin/
popd

# Allow execute permissions
chmod +x /usr/bin/azcopy

# remove tarball from azcopy
rm -rf *.tar.gz
