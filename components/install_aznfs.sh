#!/bin/bash
set -ex

source ${UTILS_DIR}/utilities.sh

# Install AZNFS Mount Helper
# Set non-interactive mode to prevent TTY prompts (required for Packer builds)
export AZNFS_NONINTERACTIVE_INSTALL=1

# Prefer PMC-published packages where available; fall back to the upstream
# AZNFS-mount GitHub installer for distros where PMC does not (yet) ship a
# native package — currently Azure Linux 3.0 (no PMC pool) and Ubuntu 26.04
# (PMC's ubuntu/26.04/prod pool does not yet ship aznfs as of Apr 2026).
# TODO(ubuntu26.04): drop the U26 carve-out and let it use the apt path
# below once PMC publishes aznfs for resolute.
if [[ $DISTRIBUTION == *"ubuntu"* && "$DISTRIBUTION" != "ubuntu26.04" ]]; then
    apt install -y aznfs
elif [[ $DISTRIBUTION == *"almalinux"* || $DISTRIBUTION == *"rocky"* || $DISTRIBUTION == *"rhel"* ]]; then
    dnf install -y aznfs
else
    # Azure Linux 3.0, Ubuntu 26.04, and any future distro without a PMC
    # aznfs package: use the upstream installer, which auto-detects the
    # distro and apt/dnf-installs the matching .deb/.rpm.
    aznfs_metadata=$(get_component_config "aznfs")
    AZNFS_VERSION=$(jq -r '.version' <<< $aznfs_metadata)
    AZNFS_SHA256=$(jq -r '.sha256' <<< $aznfs_metadata)
    AZNFS_DOWNLOAD_URL=https://github.com/Azure/AZNFS-mount/releases/download/${AZNFS_VERSION}/aznfs_install.sh

    download_and_verify $AZNFS_DOWNLOAD_URL $AZNFS_SHA256
    # Azure Linux uses tdnf, not yum/dnf; the upstream installer hardcodes yum.
    if [[ $DISTRIBUTION == *"azurelinux"* ]]; then
        sed -i 's/yum/tdnf/' aznfs_install.sh
    fi
    bash aznfs_install.sh
    rm -f aznfs_install.sh
fi