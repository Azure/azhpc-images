#!/bin/bash
set -ex

# Get the kernel
apt install -y linux-image-unsigned-5.4.0-1040-azure/bionic-updates

sudo reboot