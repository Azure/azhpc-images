#!/bin/bash
set -euo pipefail

# Post-reboot cleanup after prerequisites

echo "=========================================="
echo "Post-reboot: System cleanup and verification"
echo "=========================================="
echo "Kernel version: $(uname -r)"
echo "System uptime: $(uptime)"

if command -v dnf &> /dev/null; then
    echo "Cleaning up old kernels..."
    # Remove old kernels for RHEL-based distros
    dnf remove -y --oldinstallonly || true
    dnf list installed
fi

if command -v dpkg-query &> /dev/null; then
    dpkg-query -l
fi
