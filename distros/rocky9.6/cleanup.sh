#!/bin/bash
# Comprehensive cleanup script

echo "Cleaning up previous installations..."

# Stop any running processes
sudo pkill -f install.sh

# Clean up /opt installations
sudo rm -rf /opt/hpcx-*
sudo rm -rf /opt/openmpi-*
sudo rm -rf /opt/mvapich-*
sudo rm -rf /opt/pmix
sudo rm -rf /opt/intel/oneapi/mpi
sudo rm -rf /opt/azurehpc

# Clean up module files
sudo rm -rf /mpi
sudo rm -rf /usr/share/modulefiles/mpi

# Clean up working directory (assumes standard azhpc-images location)
if [ -d "/home/azureuser/azhpc-images/distros/rocky9.6" ]; then
    cd /home/azureuser/azhpc-images/distros/rocky9.6
    sudo rm -rf hpcx-*
    sudo rm -rf openmpi-*
    sudo rm -rf mvapich-*
    sudo rm -f *.rpm *.tar.gz *.tbz *.bz2 *.run *.sh.1 *_offline.sh
    sudo rm -f *.log
fi

echo "Cleanup complete!"
