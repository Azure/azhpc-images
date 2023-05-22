#!/bin/bash
set -e

DEST_DIR=/opt/azurehpc/tools
mkdir -p $DEST_DIR

wget https://raw.githubusercontent.com/microsoft/lis-test/master/WS2012R2/lisa/tools/KVP/kvp_client.c

cp ./kvp_client.c $DEST_DIR

gcc $DEST_DIR/kvp_client.c -o $DEST_DIR/kvp_client
