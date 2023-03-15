#!/bin/bash
set -ex

## Copy customization scripts to /opt/azurehpc/customizations
mkdir -p /opt/azurehpc/customizations
cp $COMMON_DIR/../customizations/* /opt/azurehpc/customizations


## Systemd service for setting up appropriate customizations based on SKU
cat <<EOF >/usr/sbin/setup_sku_customizations.sh
#!/bin/bash

metadata_endpoint="http://169.254.169.254/metadata/instance?api-version=2019-06-04"
vmSize=\$(curl -H Metadata:true \$metadata_endpoint | jq -r ".compute.vmSize")
vmSize=\$(echo "\$vmSize" | awk '{print tolower(\$0)}')

## Topo file setup based on SKU
case \$vmSize in
    standard_nc*ads_a100_v4)
        /opt/azurehpc/customizations/ncv4.sh;;
    
    standard_nd96*v4)
        /opt/azurehpc/customizations/ndv4.sh;;
        
    standard_nd40rs_v2)
        /opt/azurehpc/customizations/ndv2.sh;;

    *) echo "No SKU customization for \$vmSize";;
esac

if [[ \$vmSize == standard_nd96*v4 ]]
then
    ## NVIDIA Fabric manager (only for NDv4)
    systemctl enable nvidia-fabricmanager
    systemctl start nvidia-fabricmanager
    systemctl is-active --quiet nvidia-fabricmanager

    ## load nvidia-peermem module
    modprobe nvidia-peermem
fi
EOF
chmod 755 /usr/sbin/setup_sku_customizations.sh

cat <<EOF >/etc/systemd/system/sku_customizations.service
[Unit]
Description=Customizations based on SKU
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/sbin/setup_sku_customizations.sh
RemainAfterExit=true
StandardOutput=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl enable sku_customizations
systemctl start sku_customizations
systemctl is-active --quiet sku_customizations

error_code=$?
if [ ${error_code} -ne 0 ]
then
    echo "sku_customizations service Inactive!"
    exit ${error_code}
fi
