#!/bin/bash
set -euo pipefail

# Post-reboot cleanup after prerequisites

echo "=========================================="
echo "Post-reboot: System verification and cleanup"
echo "=========================================="
echo "Kernel version: $(uname -r)"
echo "System uptime: $(uptime)"

# Remove old kernels for RHEL-based distros
if command -v dnf &> /dev/null; then
    echo "Cleaning up old kernels..."
    sudo dnf remove -y --oldinstallonly || true
fi

echo "Post-reboot cleanup complete"
