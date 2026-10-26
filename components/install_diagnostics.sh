#!/bin/bash
set -ex

DESTINATION_DIR=/opt/azurehpc/diagnostics

# The script runs through a pkexec shebang; pkexec isn't installed on every distro
# (e.g. Azure Linux 3.0).
if ! command -v pkexec > /dev/null; then
    if [[ $DISTRIBUTION == *"ubuntu"* ]]; then
        apt-get install -y pkexec
    else
        dnf install -y polkit
    fi
fi

mkdir -p $DESTINATION_DIR/schema
install -m 755 $COMPONENT_DIR/diagnostics/azhpc-diagnostics.sh $DESTINATION_DIR/azhpc-diagnostics.sh
install -m 755 $COMPONENT_DIR/diagnostics/azhpc-diagnostics-analyze.sh $DESTINATION_DIR/azhpc-diagnostics-analyze.sh
install -m 644 $COMPONENT_DIR/diagnostics/azhpc-collect-lib.sh $DESTINATION_DIR/azhpc-collect-lib.sh
install -m 644 $COMPONENT_DIR/diagnostics/schema/*.schema.json $DESTINATION_DIR/schema/

# /usr/sbin is in sudo's secure_path on all supported distros
ln -sf $DESTINATION_DIR/azhpc-diagnostics.sh /usr/sbin/azhpc-diagnostics
