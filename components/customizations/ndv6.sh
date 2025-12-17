#!/bin/bash
set -ex

# Place NDv6 customizations under /opt/microsoft/ndv6
mkdir -p /opt/microsoft/ndv6

## load nvidia-peermem module
modprobe nvidia-peermem