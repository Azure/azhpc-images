#!/bin/bash
set -ex

#
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

echo -e '#!/usr/bin/bash\n\nsudo modprobe amdgpu' | sudo tee rocmstartup.sh

sudo mv rocmstartup.sh /usr/local/bin/rocmstartup.sh
sudo chown :render /usr/local/bin/rocmstartup.sh
sudo chmod g+x /usr/local/bin/rocmstartup.sh

echo -e '[Unit]\n\nDescription=Runs /usr/local/bin/rocmstartup.sh\n\n' \
        | sudo tee rocmstartup.service
echo -e '[Service]\n\nExecStart=/usr/local/bin/rocmstartup.sh\n\n' \
        | sudo tee -a rocmstartup.service
echo -e '[Install]\n\nWantedBy=multi-user.target' \
        | sudo tee -a rocmstartup.service

sudo mv rocmstartup.service /etc/systemd/system/rocmstartup.service
sudo systemctl start rocmstartup
sudo systemctl enable rocmstartup
