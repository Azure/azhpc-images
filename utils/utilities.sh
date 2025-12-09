#!/bin/bash
############################################################################
# @Brief        : Function to extract component version from the versions.json file
# @Args        : (1) #Component name
# @RetVal       : json node value
############################################################################
get_component_config(){
    component=$1
  
    config=$(jq -r '."'"${component}"'"."'"${DISTRIBUTION}"'"' <<< "${COMPONENT_VERSIONS}")
    if [[ "$config" = "null" ]]; then
        config=$(jq -r '."'"${component}"'".common' <<< "${COMPONENT_VERSIONS}")
    fi
    
    echo "$config"
}

############################################################################
# @Brief	: Write the component and its version
#
# @Args		: (1) Component Name
# 			  (2) Version
############################################################################
write_component_version(){
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
}

############################################################################
# @Brief	: Download the file and verify its checksum
#
# @Args		: (1) Download URL
# 			  (2) SHA256 CHECKSUM
############################################################################
download_and_verify(){
    DOWNLOAD_URL=$1
    DOWNLOADED_FILE_NAME=$(basename $1)
    FILE_CHECKSUM=$2
    FILE_PATH=$3

    if [ $# -eq 2 ] || [ $# -eq 3 ]
    then
        wget --retry-connrefused --tries=3 --waitretry=5 $DOWNLOAD_URL
        verify_checksum $(readlink -f $DOWNLOADED_FILE_NAME) $FILE_CHECKSUM
        if [ -n "$FILE_PATH" ]; then
            mkdir -p $FILE_PATH
            mv $DOWNLOADED_FILE_NAME $FILE_PATH
        fi
    else
        echo "*** Error - Invalid inputs!"
        return 1
    fi
    return 0
}

# Find and verify checksum
verify_checksum() {
    local checksum=`sha256sum $1 | awk '{print $1}'`
    if [[ $checksum == $2 ]]
    then
        echo "Checksum verified!"
    else
        echo "*** Error - Checksum verification failed"
        return 1
    fi
}