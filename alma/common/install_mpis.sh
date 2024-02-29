#!/bin/bash
set -ex

export GCC_VERSION=$(jq -r '.gcc."'"$DISTRIBUTION"'".version' <<< $COMPONENT_VERSIONS)

$COMMON_DIR/install_mpis.sh

# exclude updates on certain packages
sed -i "$ s/$/ ucx*/" /etc/dnf/dnf.conf
sed -i "$ s/$/ openmpi perftest/" /etc/dnf/dnf.conf
