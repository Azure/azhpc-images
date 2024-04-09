#!/bin/bash
set -ex

# Download NV Peer Memory (GPU Direct RDMA)
NV_PEER_MEMORY_VERSION="1.3-0"
NV_PEER_MEMORY_VERSION_PREFIX=$(echo ${NV_PEER_MEMORY_VERSION} | awk -F- '{print $1}')
TARBALL="${NV_PEER_MEMORY_VERSION}.tar.gz"
NV_PEER_MEM_DOWNLOAD_URL="https://github.com/Mellanox/nv_peer_memory/archive/refs/tags/${TARBALL}"
wget ${NV_PEER_MEM_DOWNLOAD_URL}
tar -xvf $TARBALL

# Build and install NV Peer Memory
pushd nv_peer_memory-${NV_PEER_MEMORY_VERSION}

# ./build_module.sh's rpmbuild command does not work, following "simialr" steps below
tmpdir=$(mktemp -d /tmp/nv.XXXXXX)
cp -r . $tmpdir/nvidia_peer_memory-$NV_PEER_MEMORY_VERSION_PREFIX

pushd $tmpdir > /dev/null
tar czf nvidia_peer_memory-$NV_PEER_MEMORY_VERSION_PREFIX.tar.gz  --exclude='.*' --exclude=build_release.sh nvidia_peer_memory-$NV_PEER_MEMORY_VERSION_PREFIX
popd > /dev/null

echo "Building source rpm for nvidia_peer_memory..."
mkdir -p $tmpdir/topdir/{SRPMS,RPMS,SPECS,BUILD,SOURCES}
cp $tmpdir/nvidia_peer_memory-$NV_PEER_MEMORY_VERSION_PREFIX.tar.gz $tmpdir/topdir/SOURCES/
rpmbuild -bb --nodeps --define "_topdir $tmpdir/topdir" --define 'dist %{nil}' --define '_source_filedigest_algorithm md5' --define '_binary_filedigest_algorithm md5' $tmpdir/nvidia_peer_memory-$NV_PEER_MEMORY_VERSION_PREFIX/nvidia_peer_memory.spec
rpm -ivh $tmpdir/topdir/RPMS/x86_64/nvidia_peer_memory-$NV_PEER_MEMORY_VERSION.x86_64.rpm

popd

lsmod | grep nv_peer_mem

$COMMON_DIR/write_component_version.sh "NV_PEER_MEMORY" ${NV_PEER_MEMORY_VERSION}
