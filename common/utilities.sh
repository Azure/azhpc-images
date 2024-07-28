#!/bin/bash

# @Brief        : Function to extract component version from the versions.json file
# @Param        : (1) #Component name
# @RetVal       : json node value
####
get_component_config(){
    component=$1
  
    config=$(jq -r '."'"${component}"'"."'"${DISTRIBUTION}"'"' <<< "${COMPONENT_VERSIONS}")
    if [[ "$config" = "null" ]]; then
        config=$(jq -r '."'"${component}"'".common' <<< "${COMPONENT_VERSIONS}")
    fi
    
    echo "$config"
}
