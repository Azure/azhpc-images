#!/bin/bash
set -e

# Kernel Parameter to disable predictive network interface naming
KERNEL_PARAMETER="net.ifnames=0"
GRUB_CMDLINE_LINUX="$GRUB_CMDLINE_LINUX console=tty1 console=ttyS0 earlyprintk=ttyS0"

# Update 50-cloudimg-settings.cfg with additional kernel parameter
sed -i "s/${GRUB_CMDLINE_LINUX}/${GRUB_CMDLINE_LINUX} ${KERNEL_PARAMETER}/" /etc/default/grub.d/50-cloudimg-settings.cfg
# Generate grub file with updated parameters 
update-grub
