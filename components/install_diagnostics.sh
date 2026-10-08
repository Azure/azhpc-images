#!/bin/bash
set -ex

DESTINATION_DIR=/opt/azurehpc/diagnostics

mkdir -p $DESTINATION_DIR
install -m 755 $COMPONENT_DIR/diagnostics/azhpc-diagnostics.sh $DESTINATION_DIR/azhpc-diagnostics.sh

# /usr/sbin is in sudo's secure_path on all supported distros
ln -sf $DESTINATION_DIR/azhpc-diagnostics.sh /usr/sbin/azhpc-diagnostics
