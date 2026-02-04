#!/bin/bash
set -euo pipefail

# Reboot after prerequisites (LTS kernel switch requires reboot)
# Use background sleep + reboot to allow SSH to disconnect gracefully

echo "Rebooting to apply kernel and system changes..."
(sleep 5 && sudo reboot) &
