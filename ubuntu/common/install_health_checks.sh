#!/bin/bash


set -e

AZHC_VERSION=v0.1.0


pushd /opt/azurehpc/test/

git clone https://github.com/Azure/azurehpc-health-checks.git --branch $AZHC_VERSION

pushd azurehpc-health-checks

NHC_VERSION=1.4.3
echo "Installed NHC verison $NHC_VERSION"

wget -O nhc-$NHC_VERSION.tar.xz https://github.com/mej/nhc/releases/download/${NHC_VERSION}/lbnl-nhc-${NHC_VERSION}.tar.xz
tar -xf nhc-$NHC_VERSION.tar.xz

pushd lbnl-nhc-$NHC_VERSION
./configure --prefix=/usr --sysconfdir=/etc --libexecdir=/usr/libexec

sudo make test
echo -e "\n"
sudo make install
popd

echo -e "\nRunning set up script for custom tests"
pushd customTests/
./custom-test-setup.sh
popd

$COMMON_DIR/write_component_version.sh "MONEO" ${AZHC_VERSION}
