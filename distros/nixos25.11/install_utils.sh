#!/bin/bash
set -ex

echo "NixOS 25.11 environment setup"

NIXOS_VERSION=$(nixos-version 2>/dev/null || echo "unknown")
KERNEL_VERSION=$(uname -r)
ARCH=$(uname -m)

echo "NixOS Version: $NIXOS_VERSION"
echo "Kernel: $KERNEL_VERSION"
echo "Architecture: $ARCH"

nix-channel --list

echo "Installing build dependencies via nix-env"
nix-env -iA nixpkgs.gcc nixpkgs.gnumake nixpkgs.cmake nixpkgs.pkg-config
nix-env -iA nixpkgs.autoconf nixpkgs.automake nixpkgs.libtool
nix-env -iA nixpkgs.python312 nixpkgs.jq nixpkgs.curl nixpkgs.wget
nix-env -iA nixpkgs.pciutils nixpkgs.numactl nixpkgs.hwloc
nix-env -iA nixpkgs.rdma-core nixpkgs.libibverbs nixpkgs.perftest
nix-env -iA nixpkgs.ethtool nixpkgs.iproute2

echo "Installed packages:"
nix-env -q
