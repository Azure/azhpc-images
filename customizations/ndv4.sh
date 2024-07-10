#!/bin/bash
set -ex

# Place NDv4 topo file under /opt/microsoft/ndv4
mkdir -p /opt/microsoft/ndv4

# Link the NDv4 topology file into /opt/microsoft/ndv4/
ln -sf /opt/microsoft/ndv4-topo.xml /opt/microsoft/ndv4/topo.xml

error_code=$?
if [ ${error_code} -ne 0 ]
then
    echo "NVIDIA Fabic Manager Inactive!"
    exit ${error_code}
fi

# ## Setup NVME devices
# if [ ! -f /etc/systemd/system/nvme-raid.service ]; then
#     /opt/azurehpc/customizations/setup_nvme.sh
# fi

# ## NVME raid service
# systemctl enable nvme-raid
# systemctl start nvme-raid
# systemctl is-active --quiet nvme-raid

# error_code=$?
# if [ ${error_code} -ne 0 ]
# then
#     echo "Failed to setup/ mount NVMe devices!"
#     exit ${error_code}
# fi
