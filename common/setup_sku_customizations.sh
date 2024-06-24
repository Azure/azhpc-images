#!/bin/bash
set -ex

## Copy customization scripts to /opt/azurehpc/customizations
mkdir -p /opt/azurehpc/customizations
cp $COMMON_DIR/../customizations/* /opt/azurehpc/customizations

## Copy topology files to /opt/microsoft
mkdir -p /opt/microsoft
chmod 644 $COMMON_DIR/../topology/* # Ensure read permission is set of others
cp $COMMON_DIR/../topology/* /opt/microsoft

## Systemd service for setting up appropriate customizations based on SKU
cat <<EOF >/usr/sbin/setup_sku_customizations.sh
#!/bin/bash

metadata_endpoint="http://169.254.169.254/metadata/instance?api-version=2019-06-04"
vmSize=\$(curl -s -H Metadata:true \$metadata_endpoint | jq -r ".compute.vmSize")

retry_count=0
while [ -z "\${vmSize}" ] && (( retry_count++ < 5 ))
do
    sleep 30
    vmSize=\$(curl -s -H Metadata:true \$metadata_endpoint | jq -r ".compute.vmSize")
done

if [ -z "\${vmSize}" ]
then
    echo "Error! Could not retrieve VM Size from IMDS endpoint"
    exit 1
fi

vmSize=\$(echo "\$vmSize" | awk '{print tolower(\$0)}')

## Topo file setup based on SKU
case \$vmSize in
    standard_nc96ads_a100_v4)
        /opt/azurehpc/customizations/ncv4.sh;;
    
    standard_nd*v4)
        /opt/azurehpc/customizations/ndv4.sh;;
        
    standard_nd40rs_v2)
        /opt/azurehpc/customizations/ndv2.sh;;

    standard_hb176*v4)
        /opt/azurehpc/customizations/hbv4.sh;;

    standard_nd96is*_h100_v5)
        /opt/azurehpc/customizations/ndv5.sh;;

    *) echo "No SKU customization for \$vmSize";;
esac
EOF
chmod 755 /usr/sbin/setup_sku_customizations.sh

## Systemd service for removing SKU based customizations
cat <<EOF >/usr/sbin/remove_sku_customizations.sh
#!/bin/bash

# Stop nvidia fabric manager
if systemctl is-active --quiet nvidia-fabricmanager
then
    systemctl stop nvidia-fabricmanager
    systemctl disable nvidia-fabricmanager
fi

# Stop nvme raid service
# if systemctl is-active --quiet nvme-raid
# then
#     systemctl stop nvme-raid
#     systemctl disable nvme-raid
# fi

# Remove NVIDIA peer memory module
if lsmod | grep nvidia_peermem &> /dev/null
then 
    rmmod nvidia_peermem
fi

# Mariner only
if lsmod | grep nv_peer_mem &> /dev/null
then 
    rmmod nv_peer_mem
    rpm -e nvidia_peer_memory
fi

# Clear topo and graph files
rm -rf /opt/microsoft/ncv4
rm -rf /opt/microsoft/ndv2
rm -rf /opt/microsoft/ndv4
rm -rf /opt/microsoft/ndv5

# Clear contents of nccl.conf
cat /dev/null > /etc/nccl.conf

EOF
chmod 755 /usr/sbin/remove_sku_customizations.sh

cat <<EOF >/etc/systemd/system/sku-customizations.service
[Unit]
Description=Customizations based on SKU
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/sbin/setup_sku_customizations.sh
ExecStop=/usr/sbin/remove_sku_customizations.sh
RemainAfterExit=true
StandardOutput=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl enable sku-customizations
systemctl start sku-customizations
systemctl is-active --quiet sku-customizations

error_code=$?
if [ ${error_code} -ne 0 ]
then
    echo "SKU Customizations service Inactive!"
    exit ${error_code}
fi
