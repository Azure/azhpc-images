#!/bin/bash

set -e

MONITOR_DIR=/opt/azurehpc/monitoring
MON_TOOLS_DIR=../monitoring_tools

mkdir -p $MONITOR_DIR

cp -r $MON_TOOLS_DIR/* $MONITOR_DIR

