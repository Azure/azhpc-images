#!/bin/bash
set -ex

source ${COMMON_DIR}/utilities.sh

pmix_metadata=$(get_component_config "pmix")
PMIX_VERSION=$(jq -r '.version' <<< $pmix_metadata)

tdnf -y install pmix-${PMIX_VERSION}.azl3.x86_64 pmix-devel-${PMIX_VERSION}.azl3.x86_64 pmix-tools-${PMIX_VERSION}.azl3.x86_64
tdnf -y install hwloc-devel libevent-devel munge-devel

$COMMON_DIR/write_component_version.sh "PMIX" ${PMIX_VERSION}