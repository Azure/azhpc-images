#!/bin/bash
set -ex

# source ${COMMON_DIR}/utilities.sh

# waagent_metadata=$(get_component_config "waagent")
# WAAGENT_VERSION=$(jq -r '.version' <<< $waagent_metadata)

# waagent_extensions_metadata=$(get_component_config "waagent_extensions")
# WAAGENT_EXTENSIONS_VERSION=$(jq -r '.version' <<< $waagent_extensions_metadata)

# Update WALinuxAgent - for IPoIB
tdnf update -y WALinuxAgent

# Configure WALinuxAgent

$COMMON_DIR/install_waagent.sh

systemctl restart waagent
waagent_version=$(waagent --version | head -n 1 | awk -F' ' '{print $1}' | awk -F- '{print $2}')
waagent_extensions_version=$(waagent --version | tail -n1 | awk '{print $4}')
$COMMON_DIR/write_component_version.sh "WAAGENT" ${waagent_version}
$COMMON_DIR/write_component_version.sh "WAAGENT_EXTENSIONS" ${waagent_extensions_version}

# $COMMON_DIR/write_component_version.sh "WAAGENT" $(waagent --version | head -n 1 | awk -F' ' '{print $1}' | awk -F- '{print $2}')
# $COMMON_DIR/write_component_version.sh "WAAGENT_EXTENSIONS" $(waagent --version | tail -n1 | awk '{print $4}')

# $COMMON_DIR/write_component_version.sh "WAAGENT" ${WAAGENT_VERSION}
# $COMMON_DIR/write_component_version.sh "WAAGENT_EXTENSIONS" ${WAAGENT_EXTENSIONS_VERSION}