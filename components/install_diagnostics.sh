#!/bin/bash
set -ex

DESTINATION_DIR=/opt/azurehpc/diagnostics

# Used by the collector and by nvidia-bug-report.sh; missing on Azure Linux 3.0
if ! command -v dmidecode > /dev/null; then
    if [[ $DISTRIBUTION == *"ubuntu"* ]]; then
        apt-get install -y dmidecode
    else
        dnf install -y dmidecode
    fi
fi

mkdir -p $DESTINATION_DIR
install -m 755 $COMPONENT_DIR/diagnostics/azhpc-diagnostics.sh $DESTINATION_DIR/azhpc-diagnostics.sh
install -m 644 $COMPONENT_DIR/diagnostics/azhpc-collect-lib.sh $DESTINATION_DIR/azhpc-collect-lib.sh
install -m 755 $COMPONENT_DIR/diagnostics/azhpc-diagnostics-facts.py $DESTINATION_DIR/azhpc-diagnostics-facts.py
install -m 755 $COMPONENT_DIR/diagnostics/azhpc-diagnostics-analyze.py $DESTINATION_DIR/azhpc-diagnostics-analyze.py

# /usr/sbin is in sudo's secure_path on all supported distros
ln -sf $DESTINATION_DIR/azhpc-diagnostics.sh /usr/sbin/azhpc-diagnostics
