#!/bin/bash
set -ex

lvextend -L +5G /dev/mapper/rootvg-optlv
lvextend -L +5G /dev/mapper/rootvg-usrlv
lvextend -L +8G /dev/mapper/rootvg-tmplv

xfs_growfs /dev/mapper/rootvg-optlv
xfs_growfs /dev/mapper/rootvg-usrlv
xfs_growfs /dev/mapper/rootvg-tmplv

cd /mnt/

wget https://github.com/Azure/azhpc-images/archive/refs/heads/master.zip
unzip master.zip 

cd azhpc-images-master/centos/centos-7.x/centos-7.9-hpc/

# Allows to install to proceed without NVLink.
sed -i 's/systemctl start nvidia-fabricmanager/systemctl start nvidia-fabricmanager || echo "systemctl start nvidia-fabricmanager failed. Does this machine have NVSwitch?"/g' ../common/install_nvidiagpudriver.sh

# AccelNet with IB is not supported for RedHat
sed -i 's/^$COMMON_DIR\/install_azure_persistent_rdma_naming.sh/#$COMMON_DIR\/install_azure_persistent_rdma_naming.sh/g' install.sh

bash ./install.sh
