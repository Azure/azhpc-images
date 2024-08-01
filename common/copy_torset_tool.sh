#!/bin/bash
set -e

DEST_DIR=/opt/azurehpc/tools
mkdir -p $DEST_DIR

cp -r $TOOLS_DIR/torset-tool $DEST_DIR
