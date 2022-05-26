#!/bin/bash
set -ex

wget -q -O - https://repo.radeon.com/rocm/rocm.gpg.key | sudo apt-key add -

wget https://repo.radeon.com/amdgpu-install/22.10.1/ubuntu/focal/amdgpu-install_22.10.1.50101-1_all.deb

sudo apt-get install -y ./amdgpu-install_22.10.1.50101-1_all.deb
sudo amdgpu-install -y  --usecase=rocm
rm amdgpu-install_22.10.1.50101-1_all.deb


#Add self to render and video groups so they can access gpus.
sudo usermod -a -G render $USER
sudo usermod -a -G video $USER

#add future new users to the render and video groups.
echo 'ADD_EXTRA_GROUPS=1' | sudo tee -a /etc/adduser.conf
echo 'EXTRA_GROUPS=video' | sudo tee -a /etc/adduser.conf
echo 'EXTRA_GROUPS=render' | sudo tee -a /etc/adduser.conf

sudo modprobe amdgpu
