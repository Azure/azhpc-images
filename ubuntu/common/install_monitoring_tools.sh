#!/bin/bash
set -ex

# Dependencies 
python3 -m pip install --upgrade pip

$COMMON_DIR/install_monitoring_tools.sh
