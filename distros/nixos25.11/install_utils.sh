#!/bin/bash
set -ex

echo "NixOS 25.11 utility functions"

NIXOS_VERSION=$(nixos-version 2>/dev/null || echo "unknown")
echo "NixOS Version: $NIXOS_VERSION"
echo "Kernel: $(uname -r)"

nix-channel --list
