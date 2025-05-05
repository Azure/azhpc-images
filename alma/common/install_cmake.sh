#!/bin/bash
set -ex

source ${COMMON_DIR}/utilities.sh

#update CMAKE
cmake_metadata=$(get_component_config "cmake")
cmake_version=$(jq -r '.version' <<< $cmake_metadata)
cmake_url=$(jq -r '.url' <<< $cmake_metadata)
cmake_sha256=$(jq -r '.sha256' <<< $cmake_metadata)
TARBALL="cmake-${cmake_version}-linux-x86_64.tar.gz"

$COMMON_DIR/download_and_verify.sh ${cmake_url} ${cmake_sha256}
tar -xzf ${TARBALL}
pushd cmake-${cmake_version}-linux-x86_64
cp -f bin/{ccmake,cmake,cpack,ctest} /usr/local/bin
cp -rf share/cmake-* /usr/local/share/
popd
hash -r

$COMMON_DIR/write_component_version.sh "CMAKE" ${cmake_version}

# Remove installation files
rm -rf cmake-${cmake_version}-linux-x86_64*
