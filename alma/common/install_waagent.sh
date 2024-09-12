#!/bin/bash
set -ex

$COMMON_DIR/install_waagent.sh

systemctl daemon-reload
systemctl restart waagent
