#!/bin/bash
set -ex

# Define the log folder and file
LOG_DIR="$HOME/setup_logs"
TIMESTAMP=$(date -u +"%Y-%m-%d_%H-%M-%S") 
LOG_FILE="$LOG_DIR/setup_output_$TIMESTAMP.log"

CURL_VERSION="7.68.0"
ENV_MODULES_VER="5.0.1"
MSTFLINT_VER="4.21.0"

# Create the log folder if it doesn't exist
if [ ! -d "$LOG_DIR" ]; then
    mkdir -p "$LOG_DIR"
fi

# Redirect all output to both the console and the log file
exec > >(tee -a "$LOG_FILE") 2>&1

print_section() {
    local section_name="$1"
    echo
    echo "===================================================================="
    echo "  SECTION: $section_name"
    echo "  TIMESTAMP: $(date -u)"
    echo "===================================================================="
    echo
}

# install pre-requisites
print_section "Install pre-requisites"
./install_prerequisites.sh

# set properties
print_section "Set properties"
source ./set_properties.sh

# remove packages requiring Ubuntu Pro for security updates
$UBUNTU_COMMON_DIR/remove_unused_packages.sh

apt update

# install curl
apt install -y curl=$CURL_VERSION*

# install modules
apt install environment-modules
apt install -y environment-modules=$ENV_MODULES_VER*

# install DOCA ALL
print_section "Install DOCA"
$UBUNTU_COMMON_DIR/install_doca.sh

# install mpi libraries
print_section "Install MPI Libraries"
$UBUNTU_COMMON_DIR/install_mpis.sh

# install nvidia gpu driver
print_section "Install NVIDIA GPU Driver"
./install_nvidiagpudriver.sh           
    
# Install NCCL
print_section "Install NCCL"
$UBUNTU_COMMON_DIR/install_nccl.sh

# Install mstflint 
sudo apt install -y mstflint=$MSTFLINT_VER*
