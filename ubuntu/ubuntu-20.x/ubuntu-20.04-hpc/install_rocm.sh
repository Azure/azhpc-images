#!/bin/bash
set -ex

#
#install extra modules to make sure modprobe works
sudo apt install -y linux-generic
ver=$(uname -r)
pack="linux-modules-extra-$ver"
sudo apt install -y $pack

wget -q -O - https://repo.radeon.com/rocm/rocm.gpg.key | sudo apt-key add -


wget -q -O - https://repo.radeon.com/rocm/rocm.gpg.key | sudo apt-key add -
amddeb="https://repo.radeon.com/amdgpu-install/22.10.1/ubuntu/focal/"
amddeb+="amdgpu-install_22.10.1.50101-1_all.deb"
wget $amddeb
sudo apt-get install -y ./amdgpu-install_22.10.1.50101-1_all.deb
sudo amdgpu-install -y --usecase=rocm


#Add self to render and video groups so they can access gpus.
sudo usermod -a -G render $(logname)
sudo usermod -a -G video $(logname)

#add future new users to the render and video groups.
echo 'ADD_EXTRA_GROUPS=1' | sudo tee -a /etc/adduser.conf
echo 'EXTRA_GROUPS=video' | sudo tee -a /etc/adduser.conf
echo 'EXTRA_GROUPS=render' | sudo tee -a /etc/adduser.conf

#update grub settings
pre=$(cat /etc/default/grub.d/50-cloudimg-settings.cfg | grep GRUB_CMDLINE_LINUX= | cut -d"\"" -f2)
string="GRUB_CMDLINE_LINUX=\"$pre amd_iommu=on iommu=pt\""
line=$(cat /etc/default/grub.d/50-cloudimg-settings.cfg | grep GRUB_CMDLINE_LINUX=)
cat /etc/default/grub.d/50-cloudimg-settings.cfg | sed -e "s/$line/$string/" > temp_file.txt
sudo mv temp_file.txt /etc/default/grub.d/50-cloudimg-settings.cfg

string="GRUB_CMDLINE_LINUX_DEFAULT=\"panic=0 nowatchdog amd_iommu=on iommu=pt\""
line=$(cat /etc/default/grub.d/50-cloudimg-settings.cfg | grep GRUB_CMDLINE_LINUX_DEFAULT=)
cat /etc/default/grub.d/50-cloudimg-settings.cfg | sed -e "s/$line/$string/" > temp_file.txt
sudo mv temp_file.txt /etc/default/grub.d/50-cloudimg-settings.cfg
sudo update-grub

