#!/bin/bash
set -ex

source ${UTILS_DIR}/utilities.sh

# Set Lustre version
lustre_metadata=$(get_component_config "lustre")
LUSTRE_VERSION=$(jq -r '.version' <<< $lustre_metadata)
RHEL_LUSTRE_VERSION=${LUSTRE_VERSION//-/_}

# Expected params:
# $1 = the major version of the distro. "8" for RHEL/Alma8, "9" for RHEL/Alma9.

source $RHEL_COMMON_DIR/setup_lustre_repo.sh "$1"

dnf install -y --disableexcludes=main --refresh amlfs-lustre-client-${RHEL_LUSTRE_VERSION}-$(uname -r | sed -e "s/\.$(uname -p)$//" | sed -re 's/[-_]/\./g')-1
sed -i "$ s/$/ amlfs*/" /etc/dnf/dnf.conf

write_component_version "LUSTRE" ${LUSTRE_VERSION}
