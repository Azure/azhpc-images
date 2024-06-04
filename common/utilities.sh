#!/bin/bash

# @Brief        : Function to extract component version from the requirements.json file
# @Param        : (1) #Key
# @RetVal       : json node value
####
get_requirements(){
    key=$1
  
    echo $(jq -r '.${key}."'"$DISTRIBUTION"'"' <<< $COMPONENT_VERSIONS)
}
