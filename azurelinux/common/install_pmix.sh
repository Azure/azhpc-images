#!/bin/bash
set -ex

source ${COMMON_DIR}/utilities.sh

pmix_metadata=$(get_component_config "pmix")
PMIX_VERSION=$(jq -r '.version' <<< $pmix_metadata)

tdnf -y install pmix pmix-devel pmix-tools
tdnf -y install hwloc-devel libevent-devel munge-devel

$COMMON_DIR/write_component_version.sh "PMIX" ${PMIX_VERSION}