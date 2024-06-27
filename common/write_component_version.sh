#!/bin/bash
############################################################################
# @Brief	: Write the component and its version
#
# @Args		: (1) Component Name
# 			  (2) Version
############################################################################

set -e

# Parameters
component=$1
version=$2

install_dir="/opt/azurehpc"
mkdir -p ${install_dir}
component_versions_json="${install_dir}/component_versions.txt"

if [ ! -f "${component_versions_json}" ]
then
    jq -n "{ \"${component}\": \"${version}\" }" > ${component_versions_json}
else
    component_versions=$(cat "${component_versions_json}")
    echo "${component_versions}" | jq ". + {\"${component}\": \"${version}\"}" > ${component_versions_json}
fi