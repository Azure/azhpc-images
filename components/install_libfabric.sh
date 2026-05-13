#!/bin/bash
set -ex

source ${UTILS_DIR}/utilities.sh

INSTALL_PREFIX=/opt/libfabric

libfabric_metadata=$(get_component_config "libfabric")
LIBFABRIC_VERSION=$(jq -r '.version' <<< $libfabric_metadata)
LIBFABRIC_SHA256=$(jq -r '.sha256' <<< $libfabric_metadata)
LIBFABRIC_DOWNLOAD_URL=$(jq -r '.url' <<< $libfabric_metadata)

TARBALL=$(basename $LIBFABRIC_DOWNLOAD_URL)
LIBFABRIC_FOLDER=$(basename $LIBFABRIC_DOWNLOAD_URL .tar.bz2)

download_and_verify ${LIBFABRIC_DOWNLOAD_URL} ${LIBFABRIC_SHA256}
tar -xvf ${TARBALL}
cd ${LIBFABRIC_FOLDER}

# Build with tcp, verbs, shm providers. Disable psm3 — it hangs on MANA-only systems.
./configure --prefix=${INSTALL_PREFIX} --disable-psm3
make -j$(nproc)
make install
cd ..

write_component_version "LIBFABRIC" ${LIBFABRIC_VERSION}
