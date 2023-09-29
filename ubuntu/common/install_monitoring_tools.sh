#!/bin/bash
set -ex

# Dependencies 
/usr/bin/python3 -m pip install --upgrade pip

$COMMON_DIR/install_monitoring_tools.sh
