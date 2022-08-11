#!/bin/bash
set -ex

cat <<EOF >/etc/init.d/set-topo.sh
#!/bin/bash


address="http://169.254.169.254/metadata/instance?api-version=2019-06-04"
vmSize=\$(curl -H Metadata:true \$address | grep -Eo '"vmSize"[^,]*' \
	| awk  -F'"' '{print \$4}')

NCskus=("Standard_NC24ads_A100_v4" "Standard_NC48ads_A100_v4")
NCSKUS+=("Standard_NC96ads_A100_v4")

isNC="False"
for sku in \${NCskus[@]};
do
	if [ \$vmSize == "\$sku" ]
	then
		isNC="True"
	fi
done

conf="/etc/nccl.conf"

if [ \$isNC == "True" ]
then
        sed -i "3s/.*/NCCL_TOPO_FILE=\/opt\/microsoft\/ncv4\/topo.xml/" \$conf
else
        sed -i "3s/.*/NCCL_TOPO_FILE=\/opt\/microsoft\/ndv4\/topo.xml/" \$conf
fi
EOF
chmod 755 /etc/init.d/set-topo.sh

echo -e '[Unit]\n\nDescription=Runs /etc/init.d/set-topo.sh\n\n' \
               | sudo tee set-topo.service
echo -e '[Service]\n\nExecStart=/etc/init.d/set-topo.sh\n\n' \
               | sudo tee -a set-topo.service
echo -e '[Install]\n\nWantedBy=multi-user.target' \
               | sudo tee -a set-topo.service



sudo mv set-topo.service /etc/systemd/system/set-topo.service
sudo systemctl enable set-topo
sudo systemctl start set-topo
