#!/bin/bash
set -ex

# Set Lustre driver version
lustre_version=$(jq -r '.lustre."'"$DISTRIBUTION"'".version' <<< $COMPONENT_VERSIONS)

# Expected params:
# $1 = the major version of the distro. "8" for RHEL/Alma8, "9" for RHEL/Alma9.

source $ALMA_COMMON_DIR/setup_lustre_repo.sh "$1"

dnf install -y --disableexcludes=main --refresh amlfs-lustre-client-$lustre_version-$(uname -r | sed -e "s/\.$(uname -p)$//" | sed -re 's/[-_]/\./g')-1
sed -i "$ s/$/ amlfs*/" /etc/dnf/dnf.conf

$COMMON_DIR/write_component_version.sh "lustre" $lustre_version
