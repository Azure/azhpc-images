#!/bin/bash
set -ex

DESTINATION_DIR='/opt/azurehpc/diagnostics'
LATEST_RELEASE_API_URL="https://api.github.com/repos/Azure/azhpc-diagnostics/releases/latest"

# example (after grep): 
# "tarball_url": "https://api.github.com/repos/Azure/azhpc-diagnostics/tarball/hpcdiag-20201201",
DOWNLOAD_URL=$(curl -s "$LATEST_RELEASE_API_URL" | grep 'tarball_url' | cut -d\" -f4)

# not using download_and_verify.sh because github doesn't provide a checksum
wget "$DOWNLOAD_URL"
DOWNLOADED_FILE_NAME=$(basename "$DOWNLOAD_URL")

TARBALL_FILES=$(tar -xzvf "$DOWNLOADED_FILE_NAME")
UNPACK_DIR=$(echo "$TARBALL_FILES" | head -1)

mkdir -p "$DESTINATION_DIR"
cp "$UNPACK_DIR/Linux/src/gather_azhpc_vm_diagnostics.sh" "$DESTINATION_DIR"

rm -r "$DOWNLOADED_FILE_NAME" "$UNPACK_DIR"
