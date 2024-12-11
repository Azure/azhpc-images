#!/bin/bash
set -e

# Define the log folder and file
LOG_DIR="/home/administrator/setup_logs"
TIMESTAMP=$(date -u +"%Y-%m-%d_%H-%M-%S") 
LOG_FILE="$LOG_DIR/setup_output_$TIMESTAMP.log"

# Create the log folder if it doesn't exist
if [ ! -d "$LOG_DIR" ]; then
    mkdir -p "$LOG_DIR"
fi

sudo chmod -R u+w "$LOG_DIR"

exec &>/dev/tty

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

# Function to check if a package is installed
install_if_missing() {
  PACKAGE_NAME=$1
  COMMAND_TO_CHECK=$2

  if ! command -v "$COMMAND_TO_CHECK" &> /dev/null; then
    echo "$PACKAGE_NAME is not installed. Installing..."
    sudo apt update
    sudo apt install -y "$PACKAGE_NAME"
  else
    echo "$PACKAGE_NAME is already installed."
  fi
}

# install pre-requisites
print_section "Install pre-requisites"
./install_prerequisites.sh

# set properties
print_section "Set properties"
source ./set_properties.sh

# remove packages requiring Ubuntu Pro for security updates
$UBUNTU_COMMON_DIR/remove_unused_packages.sh

# Check and install curl
install_if_missing "curl" "curl"

install_if_missing "cmake" "cmake"

# install utils
./install_utils.sh

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
sudo apt install -y mstflint
