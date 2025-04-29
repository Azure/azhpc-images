#!/bin/bash
set -ex

source ${COMMON_DIR}/utilities.sh

#
# install rdma_rename with NAME_FIXED option
# install rdma_rename monitor
#
rdma_core_metadata=$(get_component_config "rdma_core")
RDMA_CORE_VERSION=$(jq -r '.version' <<< $rdma_core_metadata)
RDMA_CORE_SHA=$(jq -r '.sha256' <<< $rdma_core_metadata)

TARBALL="v${RDMA_CORE_VERSION}.tar.gz"
RDMA_CORE_DOWNLOAD_URL=https://github.com/linux-rdma/rdma-core/archive/refs/tags/${TARBALL}
$COMMON_DIR/download_and_verify.sh ${RDMA_CORE_DOWNLOAD_URL} ${RDMA_CORE_SHA} /tmp

pushd /tmp
mkdir rdma-core && tar -xvf $TARBALL --strip-components=1 -C rdma-core 

pushd rdma-core
bash build.sh
cp build/bin/rdma_rename /usr/sbin/rdma_rename_$RDMA_CORE_VERSION
popd
rm -rf rdma-core
popd

#
# setup systemd service
#

cat <<EOF >/usr/sbin/azure_persistent_rdma_naming.sh
#!/bin/bash

rdma_rename=/usr/sbin/rdma_rename_${RDMA_CORE_VERSION}

an_index=0
ib_index=0

for old_device in \$(ibdev2netdev -v | sort -n | cut -f2 -d' '); do

	link_layer=\$(ibv_devinfo -d \$old_device | sed -n 's/^[\ \t]*link_layer:[\ \t]*\([a-zA-Z]*\)\$/\1/p')
	
	if [ "\$link_layer" = "InfiniBand" ]; then
		
		\$rdma_rename \$old_device NAME_FIXED mlx5_ib\${ib_index}
		ib_index=\$((\$ib_index + 1))
		
	elif [ "\$link_layer" = "Ethernet" ]; then
	
		\$rdma_rename \$old_device NAME_FIXED mlx5_an\${an_index}
		an_index=\$((\$an_index + 1))
		
	else
	
		echo "Unknown device type for \$old_device - \$device_type."
		
	fi
	
done
EOF
chmod 755 /usr/sbin/azure_persistent_rdma_naming.sh

cat <<EOF >/etc/systemd/system/azure_persistent_rdma_naming.service
[Unit]
Description=Azure persistent RDMA naming
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/sbin/azure_persistent_rdma_naming.sh
RemainAfterExit=true
StandardOutput=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl enable azure_persistent_rdma_naming.service
systemctl start azure_persistent_rdma_naming.service

$COMMON_DIR/install_azure_persistent_rdma_naming_monitor.sh      
