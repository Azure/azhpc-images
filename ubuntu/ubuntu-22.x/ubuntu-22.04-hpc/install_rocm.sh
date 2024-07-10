#!/bin/bash
set -ex

#move to rocm package
sudo ./amdgpu-install -y --usecase=graphics,rocm


#Add self to render and video groups so they can access gpus.
sudo usermod -a -G render $(logname)
sudo usermod -a -G video $(logname)

#add future new users to the render and video groups.
echo 'ADD_EXTRA_GROUPS=1' | sudo tee -a /etc/adduser.conf
echo 'EXTRA_GROUPS=video' | sudo tee -a /etc/adduser.conf
echo 'EXTRA_GROUPS=render' | sudo tee -a /etc/adduser.conf

#add nofile limits
string_so="*               soft    nofile          1048576"
line=$(cat /etc/security/limits.conf | grep "soft    nofile")
cat /etc/security/limits.conf | sed -e "s/$line/$string_so/" > temp_file.txt
sudo mv temp_file.txt /etc/security/limits.conf
string_ha="*               hard    nofile          1048576"
line=$(cat /etc/security/limits.conf | grep "hard    nofile")
cat /etc/security/limits.conf | sed -e "s/$line/$string_ha/" > temp_file.txt
sudo mv temp_file.txt /etc/security/limits.conf

cat /etc/security/limits.conf | grep -v "  stack" > tmplimits.conf
sudo mv tmplimits.conf /etc/security/limits.conf

echo blacklist amdgpu | sudo tee -a /etc/modprobe.d/blacklist.conf
sudo update-initramfs -c -k $(uname -r)

echo "Writing gpu mode probe in init.d"
bprefix="#!"
echo "$bprefix/bin/sh" > /tmp/tempinit.sh
echo "at_count=0" >> /tmp/tempinit.sh
echo 'while [ $at_count -le 90 ]' >> /tmp/tempinit.sh
echo "do" >> /tmp/tempinit.sh
echo '    if [ $(lspci -d 1002:74b5 | wc -l) -eq 8 -o $(lspci -d 1002:740c | wc -l) -eq 16 ]; then' >> /tmp/tempinit.sh
echo '       echo Required number of GPUs found' >> /tmp/tempinit.sh
echo '       at_count=91' >> /tmp/tempinit.sh
echo '       sleep 120s' >> /tmp/tempinit.sh
echo '       echo doing Modprobe for amdgpu' >> /tmp/tempinit.sh
echo "       sudo modprobe -r hyperv_drm" >> /tmp/tempinit.sh
echo "       sudo modprobe amdgpu ip_block_mask=0x7f" >> /tmp/tempinit.sh
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

sudo apt install rocm-bandwidth-test

