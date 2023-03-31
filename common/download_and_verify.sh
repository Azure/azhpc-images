#!/bin/bash
set -ex

# Parameters
download_url=$1
downloaded_file_name=$(basename $1)
file_checksum=$2

# Find and verify checksum
verify_checksum() {
    local checksum=`sha256sum $1 | awk '{print $1}'`
    if [[ $checksum != $2 ]]
    then
        echo "*** Error - Checksum verification failed"
        exit -1
    fi
    echo "Checksum verified!"
}

if [ $# -ne 2 ]
then
    echo "*** Error - Invalid inputs!"
    exit -1
fi

wget --retry-connrefused --tries=3 --waitretry=5 $download_url
verify_checksum $(readlink -f $downloaded_file_name) $file_checksum
