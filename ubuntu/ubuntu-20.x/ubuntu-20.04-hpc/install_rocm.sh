#!/bin/bash
set -ex

#
#install extra modules to make sure modprobe works
sudo apt install -y linux-generic
ver=$(uname -r)
pack="linux-modules-extra-$ver"
sudo apt install -y $pack

wget -q -O - https://repo.radeon.com/rocm/rocm.gpg.key | sudo apt-key add -
amddeb="https://repo.radeon.com/amdgpu-install/22.20.3/ubuntu/focal/"
amddeb+="amdgpu-install_22.20.50203-1_all.deb"
wget $amddeb
sudo apt-get install -y ./amdgpu-install_22.20.50203-1_all.deb
sudo amdgpu-install -y --usecase=rocm


#Add self to render and video groups so they can access gpus.
sudo usermod -a -G render $(logname)
sudo usermod -a -G video $(logname)

#add future new users to the render and video groups.
echo 'ADD_EXTRA_GROUPS=1' | sudo tee -a /etc/adduser.conf
echo 'EXTRA_GROUPS=video' | sudo tee -a /etc/adduser.conf
echo 'EXTRA_GROUPS=render' | sudo tee -a /etc/adduser.conf

#update grub settings
string="GRUB_CMDLINE_LINUX_DEFAULT=\"panic=0 nowatchdog\""
line=$(cat /etc/default/grub.d/50-cloudimg-settings.cfg | grep GRUB_CMDLINE_LINUX_DEFAULT=)
cat /etc/default/grub.d/50-cloudimg-settings.cfg | sed -e "s/$line/$string/" > temp_file.txt
sudo mv temp_file.txt /etc/default/grub.d/50-cloudimg-settings.cfg
sudo update-grub

#add nofile limits
string_so="*               soft    nofile          1048576"
line=$(cat /etc/security/limits.conf | grep "soft    nofile")
cat /etc/security/limits.conf | sed -e "s/$line/$string_so/" > temp_file.txt
sudo mv temp_file.txt /etc/security/limits.conf
string_ha="*               hard    nofile          1048576"
line=$(cat /etc/security/limits.conf | grep "hard    nofile")
cat /etc/security/limits.conf | sed -e "s/$line/$string_ha/" > temp_file.txt
sudo mv temp_file.txt /etc/security/limits.conf

echo "Writing gpu mode probe in init.d"
bprefix="#!"
echo "$bprefix/bin/sh" > /tmp/tempinit.sh
echo "at_count=0" >> /tmp/tempinit.sh
echo 'while [ $at_count -le 90 ]' >> /tmp/tempinit.sh
echo "do" >> /tmp/tempinit.sh
echo '    if [ $(lspci -d 1002:740c | wc -l) -eq 16 ]; then' >> /tmp/tempinit.sh
echo '       echo Required 16 GPU found' >> /tmp/tempinit.sh
echo '       at_count=91' >> /tmp/tempinit.sh
echo '       echo doing Modprobe for amdgpu' >> /tmp/tempinit.sh
echo "       sudo modprobe amdgpu" >> /tmp/tempinit.sh
echo '    else' >> /tmp/tempinit.sh
echo '       sleep 10' >> /tmp/tempinit.sh
echo '       at_count=$(($at_count + 1))' >> /tmp/tempinit.sh
echo '    fi' >> /tmp/tempinit.sh
echo 'done' >> /tmp/tempinit.sh
echo ""
echo "exit 0" >> /tmp/tempinit.sh
sudo cp /tmp/tempinit.sh /etc/init.d/initamdgpu.sh
sudo chmod +x /etc/init.d/initamdgpu.sh
rm /tmp/tempinit.sh

echo "Completed gpu mode probe in init.d"

echo -e '[Unit]\n\nDescription=Runs /etc/init.d/initamdgpu.sh\n\n' \
               | sudo tee rocmstartup.service
echo -e '[Service]\n\nExecStart=/etc/init.d/initamdgpu.sh\n\n' \
               | sudo tee -a rocmstartup.service
echo -e '[Install]\n\nWantedBy=multi-user.target' \
               | sudo tee -a rocmstartup.service

sudo mv rocmstartup.service /etc/systemd/system/rocmstartup.service
sudo systemctl start rocmstartup
sudo systemctl enable rocmstartup

