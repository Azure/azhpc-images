#!/bin/bash
set -ex

source ${COMMON_DIR}/utilities.sh

# To copy blobs or files to or from a storage account
azcopy_metadata=$(get_component_config "azcopy")
azcopy_version=$(jq -r '.version' <<< $azcopy_metadata)
azcopy_release=$(jq -r '.release' <<< $azcopy_metadata)
azcopy_sha256=$(jq -r '.sha256' <<< $azcopy_metadata)
TARBALL="azcopy_linux_amd64_$azcopy_version.tar.gz"
AZCOPY_DOWNLOAD_URL="https://azcopyvnext-awgzd8g7aagqhzhe.b02.azurefd.net/releases/release-${azcopy_release}/${TARBALL}"

${COMMON_DIR}/download_and_verify.sh ${AZCOPY_DOWNLOAD_URL} ${azcopy_sha256}
tar -xvf ${TARBALL}

# copy the azcopy to the bin path
pushd azcopy_linux_amd64_${azcopy_version}
cp azcopy /usr/bin/
popd

# Allow execute permissions
chmod +x /usr/bin/azcopy

$COMMON_DIR/write_component_version.sh "AZCOPY" ${azcopy_version}

# remove tarball from azcopy
rm -rf *.tar.gz
