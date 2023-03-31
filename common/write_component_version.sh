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

# Create the file if it doesn't exist
mkdir -p $HPC_ENV
component_versions_json=$HPC_ENV/component_versions.json

if [ ! -f "$component_versions_json" ]
then
    touch $HPC_ENV/component_versions.json
    component_versions=$(jq -n "{ \"$component\": \"$version\" }")
else
    component_versions=$(cat "$component_versions_json")
    component_versions=$(echo "$component_versions" | jq ". + {\"$component\": \"$version\"}")
fi

# Write the component and version to the file
echo "$component_versions" > "$component_versions_json"
