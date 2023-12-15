#!/bin/bash
set -ex

# Install common dependencies
spack add cmake \
    numactl \
    bison \
    tcl \
    slurm

spack install

cmake_home=$(spack location -i cmake)
export_cmake_path="export PATH=$(echo $cmake_home)/bin:$PATH"
eval $export_cmake_path
echo $export_cmake_path | tee -a /etc/profile
ln -s $cmake_home/bin/cmake /bin/cmake

# Install azcopy tool
# To copy blobs or files to or from a storage account
azcopy_metadata=$(jq -r '.azcopy."'"$DISTRIBUTION"'"' <<< $COMPONENT_VERSIONS)
azcopy_version=$(jq -r '.version' <<< $azcopy_metadata)
azcopy_release=$(jq -r '.release' <<< $azcopy_metadata)
azcopy_sha256=$(jq -r '.sha256' <<< $azcopy_metadata)
tarball="azcopy_linux_amd64_$azcopy_version.tar.gz"
azcopy_download_url="https://azcopyvnext.azureedge.net/$azcopy_release/$tarball"
azcopy_folder=$(basename $azcopy_download_url .tgz)

$COMMON_DIR/download_and_verify.sh $azcopy_download_url $azcopy_sha256
tar -xvf $tarball

# copy the azcopy to the bin path
pushd azcopy_linux_amd64_$azcopy_version
cp azcopy /usr/bin/
popd

$COMMON_DIR/write_component_version.sh "azcopy" $azcopy_version
