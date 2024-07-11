#!/bin/bash
set -ex

doca_metadata=$(jq -r '.doca."'"$DISTRIBUTION"'"' <<< $COMPONENT_VERSIONS)
DOCA_VERSION=$(jq -r '.version' <<< $doca_metadata)
DOCA_SHA256=$(jq -r '.sha256' <<< $doca_metadata)
DOCA_URL=$(jq -r '.url' <<< $doca_metadata)
DOCA_FILE=$(basename ${DOCA_URL})

$COMMON_DIR/download_and_verify.sh $DOCA_URL $DOCA_SHA256

rpm -i $DOCA_FILE
dnf clean all

dnf -y install doca-ofed
$COMMON_DIR/write_component_version.sh "DOCA" $DOCA_VERSION

/etc/init.d/openibd restart
