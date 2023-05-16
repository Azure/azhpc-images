#!/bin/bash
set -e

DEST_DIR=/opt/azurehpc
mkdir -p $DEST_DIR

wget https://raw.githubusercontent.com/microsoft/lis-test/master/WS2012R2/lisa/tools/KVP/kvp_client.c

cp ./kvp_client.c $DEST_DIR

# gcc /opt/azurehpc/kvp_client.c -o ./kvp_client
# ./kvp_client
