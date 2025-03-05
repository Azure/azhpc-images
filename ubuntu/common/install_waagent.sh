#!/bin/bash
set -ex

$COMMON_DIR/install_waagent.sh
systemctl restart walinuxagent
