#!/bin/bash
set -ex

# Check if arguments are passed
if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Error: Missing arguments. Please provide both GPU type (NVIDIA/AMD) and SKU."
    exit 1
fi

export GPU=$1
export SKU=$2

if [[ "$#" -gt 0 ]]; then
   if [[ "$GPU" != "NVIDIA" && "$GPU" != "AMD" ]]; then
       echo "Error: Invalid GPU type. Please specify 'NVIDIA' or 'AMD'."
       exit 1
    fi
fi

source ../../utils/set_properties.sh

# modify distribution for AKS Host Image
export DISTRIBUTION=${DISTRIBUTION}-aks

./install_utils_aks.sh

# install DOCA OFED
$COMPONENT_DIR/install_doca.sh

if [ "$GPU" = "NVIDIA" ]; then
    # install nvidia gpu driver

    if [ "$SKU" = "GB200" ]; then
        # For GB200, pass SKU to install the correct driver
        ./install_nvidiagpudriver_gb200.sh

    else
        $COMPONENT_DIR/install_nvidiagpudriver.sh "$SKU"
    fi
fi

if [ "$GPU" = "AMD" ]; then
    # TODO: Check AKS Host image requirements for AMD GPUs
    #install rocm software stack
    $COMPONENT_DIR/install_rocm.sh
fi

# cleanup downloaded tarballs - clear some space
rm -rf *.tgz *.bz2 *.tbz *.tar.gz *.run *.deb *_offline.sh
rm -rf /tmp/MLNX_OFED_LINUX* /tmp/*conf*
rm -rf /var/intel/ /var/cache/*
rm -Rf -- */

# copy test file
$COMPONENT_DIR/copy_test_file.sh

# SKU Customization
$COMPONENT_DIR/setup_sku_customizations.sh

# scan vulnerabilities using Trivy
$COMPONENT_DIR/trivy_scan.sh
# clear history
# Uncomment the line below if you are running this on a VM
# $UTILS_DIR/clear_history.sh
